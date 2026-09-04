import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:record/record.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';

import '../config.dart';
import '../models/member.dart';
import '../models/transmission.dart';
import '../utils/radio_sound_effects.dart';
import 'api_service.dart';

enum ConnectionStatus { disconnected, connecting, connected }

class WebSocketService extends ChangeNotifier {
  final String groupId;
  final String userId;
  late String _displayName;
  String get displayName => _displayName;

  // In-memory transmission history (last 5 per user)
  final List<Transmission> _transmissions = [];
  List<Transmission> get transmissions => List.unmodifiable(_transmissions);
  bool _isLoadingHistory = false;
  bool get isLoadingHistory => _isLoadingHistory;
  String? _currentlyPlayingTransmissionId;
  String? get currentlyPlayingTransmissionId => _currentlyPlayingTransmissionId;

  WebSocketChannel? _channel;
  StreamSubscription? _channelSub;
  Timer? _reconnectTimer;
  int _reconnectDelaySeconds = 1;
  bool _disposed = false;

  ConnectionStatus _status = ConnectionStatus.disconnected;
  ConnectionStatus get status => _status;

  // Multi-speaker PTT state
  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;

  final Set<String> _activeSpeakerIds = {};
  Set<String> get activeSpeakerIds => Set.unmodifiable(_activeSpeakerIds);

  final Map<String, String> _activeSpeakerNames = {};
  Map<String, String> get activeSpeakerNames => Map.unmodifiable(_activeSpeakerNames);

  // Other members currently speaking (excluding local user)
  List<String> get otherActiveSpeakerNames => _activeSpeakerNames.entries
      .where((e) => e.key != userId)
      .map((e) => e.value)
      .toList();

  String? get activeSpeakerId => _activeSpeakerIds.isNotEmpty ? _activeSpeakerIds.first : null;
  String? get activeSpeakerName => _activeSpeakerNames.isNotEmpty ? _activeSpeakerNames.values.first : null;

  // With multi-speaker full duplex, channel is never locked/busy!
  bool get isChannelBusy => false;

  // Solo Echo / Loopback mode
  bool _echoMode = false;
  bool get echoMode => _echoMode;
  set echoMode(bool value) {
    _echoMode = value;
    notifyListeners();
  }

  // Audio stats & mic level
  int _packetsSent = 0;
  int get packetsSent => _packetsSent;

  int _packetsReceived = 0;
  int get packetsReceived => _packetsReceived;

  double _micLevel = 0.0;
  double get micLevel => _micLevel;

  bool _isGroupDeleted = false;
  bool get isGroupDeleted => _isGroupDeleted;

  // Group membership presence
  final List<Member> _members = [];
  List<Member> get members => List.unmodifiable(_members);

  // Audio recording
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<Uint8List>? _recordSub;
  List<int> _audioBuffer = [];

  // Power State: active (transmitting & receiving) vs standby (power off)
  bool _isPoweredOn = true;
  bool get isPoweredOn => _isPoweredOn;

  // Audio gain multiplier (boosts mic volume so other side hears clearly)
  double _audioGain = 2.5;
  double get audioGain => _audioGain;
  set audioGain(double val) {
    _audioGain = val;
    notifyListeners();
  }

  // Jitter buffer queue for smooth audio playback
  final List<Uint8List> _playbackQueue = [];
  bool _isPlayingQueue = false;

  // Audio playback
  bool _soundInitialized = false;

  WebSocketService({
    required this.groupId,
    required this.userId,
    required String displayName,
  }) {
    _displayName = displayName;
    _initAudioPlayer();
    connect();
    loadHistory();
  }

  void updateDisplayName(String newName) {
    _displayName = newName;
    final index = _members.indexWhere((m) => m.userId == userId);
    if (index != -1) {
      _members[index] = _members[index].copyWith(displayName: newName);
    }
    if (_activeSpeakerNames.containsKey(userId)) {
      _activeSpeakerNames[userId] = newName;
    }
    if (_channel != null && _status == ConnectionStatus.connected) {
      _channel!.sink.add(jsonEncode({
        'type': 'update_display_name',
        'user_id': userId,
        'display_name': newName,
      }));
    }
    notifyListeners();
  }

  Future<void> loadHistory() async {
    _isLoadingHistory = true;
    notifyListeners();
    try {
      final list = await ApiService.getGroupAudioHistory(groupId);
      _transmissions.clear();
      for (var item in list) {
        _transmissions.add(Transmission.fromJson(item as Map<String, dynamic>));
      }
    } catch (e) {
      debugPrint('Error loading audio history: $e');
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  bool _stopReplayRequested = false;

  /// Play classic walkie-talkie radio key-up opening chirp
  void playStartChirp() {
    if (!_soundInitialized || !_isPoweredOn) return;
    try {
      final pcmBytes = RadioSoundEffects.generateStartChirp();
      final bd = pcmBytes.buffer.asByteData(pcmBytes.offsetInBytes, pcmBytes.lengthInBytes);
      FlutterPcmSound.feed(PcmArrayInt16(bytes: bd));
    } catch (e) {
      debugPrint('Error playing start chirp: $e');
    }
  }

  /// Play classic walkie-talkie roger beep and squelch tail ("BEEP - ksh")
  void playEndRogerBeep() {
    if (!_soundInitialized || !_isPoweredOn) return;
    try {
      final pcmBytes = RadioSoundEffects.generateEndRogerBeep();
      final bd = pcmBytes.buffer.asByteData(pcmBytes.offsetInBytes, pcmBytes.lengthInBytes);
      FlutterPcmSound.feed(PcmArrayInt16(bytes: bd));
    } catch (e) {
      debugPrint('Error playing end roger beep: $e');
    }
  }

  Future<void> replayTransmission(Transmission tx) async {
    if (_currentlyPlayingTransmissionId != null) return;
    _currentlyPlayingTransmissionId = tx.id;
    _stopReplayRequested = false;
    notifyListeners();

    try {
      // 1. Play opening radio chirp before audio
      playStartChirp();
      await Future.delayed(const Duration(milliseconds: 110));

      final pcmBytes = await ApiService.getTransmissionRawPcm(tx.id);
      if (pcmBytes.isNotEmpty && !_stopReplayRequested) {
        _playAudioChunk(Uint8List.fromList(pcmBytes));
        _drainPlaybackQueue();
        final durationMs = (tx.durationSeconds * 1000).round();
        const stepMs = 50;
        int elapsed = 0;
        while (elapsed < durationMs && !_stopReplayRequested) {
          await Future.delayed(const Duration(milliseconds: stepMs));
          elapsed += stepMs;
        }

        // 2. Play ending roger beep after audio finishes
        if (!_stopReplayRequested) {
          playEndRogerBeep();
          await Future.delayed(const Duration(milliseconds: 120));
        }
      }
    } catch (e) {
      debugPrint('Error replaying transmission: $e');
    } finally {
      _currentlyPlayingTransmissionId = null;
      _stopReplayRequested = false;
      notifyListeners();
    }
  }

  void stopReplay() {
    _stopReplayRequested = true;
    _currentlyPlayingTransmissionId = null;
    _flushPlaybackQueue();
    notifyListeners();
  }

  Future<void> _initAudioPlayer() async {
    try {
      await FlutterPcmSound.setup(
        sampleRate: AppConfig.sampleRate,
        channelCount: AppConfig.channels,
      );
      await FlutterPcmSound.setLogLevel(LogLevel.none);
      _soundInitialized = true;
    } catch (e) {
      debugPrint('Error initializing FlutterPcmSound: $e');
    }
  }

  void togglePower() {
    if (_isPoweredOn) {
      // Power OFF -> Disconnect WS, release PTT, clear queues
      _isPoweredOn = false;
      if (_isSpeaking) {
        stopPTT();
      }
      _playbackQueue.clear();
      _channelSub?.cancel();
      _channelSub = null;
      _channel?.sink.close();
      _channel = null;
      _status = ConnectionStatus.disconnected;
      _activeSpeakerIds.clear();
      _activeSpeakerNames.clear();
      notifyListeners();
    } else {
      // Power ON -> Connect WS, resume listening
      _isPoweredOn = true;
      connect();
    }
  }

  void connect() {
    if (_disposed || _status == ConnectionStatus.connected) return;

    _status = ConnectionStatus.connecting;
    notifyListeners();

    final encodedName = Uri.encodeComponent(displayName);
    final wsUrl =
        '${AppConfig.wsBaseUrl}/ws/group/$groupId?user_id=$userId&display_name=$encodedName';

    try {
      final uri = Uri.parse(wsUrl);
      _channel = WebSocketChannel.connect(uri);

      _channelSub = _channel!.stream.listen(
        _onMessageReceived,
        onDone: _onDisconnected,
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _onDisconnected();
        },
        cancelOnError: true,
      );

      _status = ConnectionStatus.connected;
      _reconnectDelaySeconds = 1; // Reset backoff on success
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to connect WebSocket: $e');
      _onDisconnected();
    }
  }

  void _onDisconnected() {
    if (_disposed) return;

    _status = ConnectionStatus.disconnected;
    // Release active PTT immediately on disconnect
    if (_isSpeaking) {
      _stopRecording();
      _isSpeaking = false;
    }
    _activeSpeakerIds.clear();
    _activeSpeakerNames.clear();
    notifyListeners();

    // Exponential backoff reconnect: 1s, 2s, 4s, max 8s
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _reconnectDelaySeconds), () {
      _reconnectDelaySeconds = (_reconnectDelaySeconds * 2).clamp(1, 8);
      connect();
    });
  }

  void _onMessageReceived(dynamic message) {
    if (message is String) {
      // JSON control event
      try {
        final data = jsonDecode(message) as Map<String, dynamic>;
        _handleJsonEvent(data);
      } catch (e) {
        debugPrint('Error decoding JSON from WS: $e');
      }
    } else if (message is List<int>) {
      // Binary audio frame from another speaking member
      _playAudioChunk(Uint8List.fromList(message));
    }
  }

  void _handleJsonEvent(Map<String, dynamic> data) {
    final type = data['type'] as String?;

    switch (type) {
      case 'initial_state':
        final rawMembers = data['online_members'] as List<dynamic>? ?? [];
        _members.clear();
        for (var item in rawMembers) {
          final m = item as Map<String, dynamic>;
          _members.add(Member(
            userId: m['user_id'] as String,
            displayName: m['display_name'] as String,
            isOnline: true,
          ));
        }
        _activeSpeakerIds.clear();
        _activeSpeakerNames.clear();
        final speakerIds = (data['active_speaker_ids'] as List<dynamic>?)?.cast<String>() ?? [];
        final speakerNames = (data['active_speaker_names'] as List<dynamic>?)?.cast<String>() ?? [];
        for (int i = 0; i < speakerIds.length; i++) {
          final sId = speakerIds[i];
          final sName = i < speakerNames.length ? speakerNames[i] : 'Speaker';
          _activeSpeakerIds.add(sId);
          _activeSpeakerNames[sId] = sName;
        }
        notifyListeners();
        break;

      case 'user_joined':
        final uId = data['user_id'] as String;
        final dName = data['display_name'] as String;
        final index = _members.indexWhere((m) => m.userId == uId);
        if (index != -1) {
          _members[index] = _members[index].copyWith(isOnline: true, displayName: dName);
        } else {
          _members.add(Member(userId: uId, displayName: dName, isOnline: true));
        }
        notifyListeners();
        break;

      case 'user_left':
        final uId = data['user_id'] as String;
        final index = _members.indexWhere((m) => m.userId == uId);
        if (index != -1) {
          _members[index] = _members[index].copyWith(isOnline: false);
        }
        _activeSpeakerIds.remove(uId);
        _activeSpeakerNames.remove(uId);
        notifyListeners();
        break;

      case 'ptt_started':
        final uId = data['user_id'] as String;
        final dName = data['display_name'] as String?;
        final resolvedName = dName ?? (_members.firstWhere((m) => m.userId == uId, orElse: () => Member(userId: uId, displayName: 'Member')).displayName);
        _activeSpeakerIds.add(uId);
        _activeSpeakerNames[uId] = resolvedName;
        if (uId == userId) {
          _isSpeaking = true;
        } else {
          // Play classic walkie-talkie opening chirp before incoming voice begins
          playStartChirp();
        }
        notifyListeners();
        break;

      case 'ptt_stopped':
        final uId = data['user_id'] as String;
        _activeSpeakerIds.remove(uId);
        _activeSpeakerNames.remove(uId);
        if (uId == userId) {
          _isSpeaking = false;
        } else {
          // Play classic walkie-talkie roger beep + squelch tail when incoming transmission ends
          playEndRogerBeep();
        }
        // If a new transmission was recorded, prepend to history
        if (data['transmission'] != null) {
          try {
            final tx = Transmission.fromJson(data['transmission'] as Map<String, dynamic>);
            _transmissions.removeWhere((t) => t.id == tx.id);
            _transmissions.insert(0, tx);
          } catch (e) {
            debugPrint('Error parsing transmission event: $e');
          }
        }
        // Drain any remaining playback queue
        _flushPlaybackQueue();
        notifyListeners();
        break;

      case 'ptt_rejected':
        // Channel was busy, cancel local speaking state
        _stopRecording();
        _isSpeaking = false;
        notifyListeners();
        break;

      case 'user_updated':
        final uId = data['user_id'] as String?;
        final dName = data['display_name'] as String?;
        if (uId != null && dName != null) {
          final index = _members.indexWhere((m) => m.userId == uId);
          if (index != -1) {
            _members[index] = _members[index].copyWith(displayName: dName);
          }
          if (_activeSpeakerNames.containsKey(uId)) {
            _activeSpeakerNames[uId] = dName;
          }
          notifyListeners();
        }
        break;

      case 'group_renamed':
        final gId = data['group_id'] as String?;
        final gName = data['name'] as String?;
        if (gId == groupId && gName != null) {
          notifyListeners();
        }
        break;

      case 'group_deleted':
        _isGroupDeleted = true;
        _isSpeaking = false;
        _stopRecording();
        notifyListeners();
        break;
    }
  }

  void _playAudioChunk(Uint8List pcmBytes) {
    if (!_soundInitialized || pcmBytes.isEmpty || !_isPoweredOn) return;
    try {
      _packetsReceived++;
      notifyListeners();

      // Apply software digital gain to 16-bit PCM samples to boost volume
      final amplified = Uint8List(pcmBytes.length);
      final byteData = pcmBytes.buffer.asByteData(pcmBytes.offsetInBytes, pcmBytes.lengthInBytes);
      final outByteData = amplified.buffer.asByteData();

      for (int i = 0; i < pcmBytes.length - 1; i += 2) {
        int sample = byteData.getInt16(i, Endian.little);
        int boosted = (sample * _audioGain).round().clamp(-32768, 32767);
        outByteData.setInt16(i, boosted, Endian.little);
      }

      // Add to playback queue
      _playbackQueue.add(amplified);

      // Start playing queue if not already running
      if (!_isPlayingQueue) {
        // Require at least 2 chunks (~80ms) for jitter resistance before starting
        if (_playbackQueue.length >= 2) {
          _drainPlaybackQueue();
        }
      }
    } catch (e) {
      debugPrint('Error processing audio chunk: $e');
    }
  }

  void _drainPlaybackQueue() {
    _isPlayingQueue = true;
    while (_playbackQueue.isNotEmpty) {
      final chunk = _playbackQueue.removeAt(0);
      try {
        final bd = chunk.buffer.asByteData(chunk.offsetInBytes, chunk.lengthInBytes);
        FlutterPcmSound.feed(PcmArrayInt16(bytes: bd));
      } catch (e) {
        debugPrint('Error feeding audio to FlutterPcmSound: $e');
      }
    }
    _isPlayingQueue = false;
  }

  void _flushPlaybackQueue() {
    if (_playbackQueue.isNotEmpty) {
      _drainPlaybackQueue();
    }
  }

  /// Request Push-to-Talk lock from server and start mic streaming
  Future<void> startPTT() async {
    if (_status != ConnectionStatus.connected || isChannelBusy || _isSpeaking) {
      return;
    }

    final hasPerm = await _audioRecorder.hasPermission();
    if (!hasPerm) {
      debugPrint('Microphone permission denied.');
      return;
    }

    // 1. Send ptt_start signal with echo preference
    _channel?.sink.add(jsonEncode({
      'type': 'ptt_start',
      'echo': _echoMode,
    }));
    _isSpeaking = true;
    _packetsSent = 0;
    _micLevel = 0.0;
    notifyListeners();

    // 2. Start recording stream (PCM 16-bit 16kHz mono)
    try {
      final audioStream = await _audioRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: AppConfig.sampleRate,
          numChannels: AppConfig.channels,
        ),
      );

      _audioBuffer.clear();
      _recordSub = audioStream.listen((chunk) {
        if (!_isSpeaking) return;

        // Calculate peak amplitude from 16-bit PCM for live visual soundwave
        double peak = 0.0;
        for (int i = 0; i < chunk.length - 1; i += 2) {
          int s = chunk[i] | (chunk[i + 1] << 8);
          if (s > 32767) s -= 65536;
          final val = s.abs();
          if (val > peak) peak = val.toDouble();
        }
        _micLevel = (peak / 32768.0).clamp(0.0, 1.0);

        // Buffer into 40ms frames (~1280 bytes) before sending over WebSocket
        _audioBuffer.addAll(chunk);
        while (_audioBuffer.length >= AppConfig.frameChunkSize) {
          final frame = _audioBuffer.sublist(0, AppConfig.frameChunkSize);
          _channel?.sink.add(Uint8List.fromList(frame));
          _packetsSent++;
          _audioBuffer = _audioBuffer.sublist(AppConfig.frameChunkSize);
        }
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Error starting audio recorder stream: $e');
      stopPTT();
    }
  }

  /// Stop mic recording and release Push-to-Talk lock
  Future<void> stopPTT() async {
    if (!_isSpeaking) return;

    _isSpeaking = false;
    _micLevel = 0.0;
    await _stopRecording();

    // Flush any remaining buffered audio bytes
    if (_audioBuffer.isNotEmpty) {
      _channel?.sink.add(Uint8List.fromList(_audioBuffer));
      _packetsSent++;
      _audioBuffer.clear();
    }

    // Play local end roger beep & squelch on PTT release
    playEndRogerBeep();

    // Send ptt_stop signal
    _channel?.sink.add(jsonEncode({'type': 'ptt_stop'}));
    notifyListeners();
  }

  Future<void> _stopRecording() async {
    await _recordSub?.cancel();
    _recordSub = null;
    try {
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }
    } catch (e) {
      debugPrint('Error stopping audio recorder: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _stopRecording();
    _channelSub?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
