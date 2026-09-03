import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:record/record.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';

import '../config.dart';
import '../models/member.dart';

enum ConnectionStatus { disconnected, connecting, connected }

class WebSocketService extends ChangeNotifier {
  final String groupId;
  final String userId;
  final String displayName;

  WebSocketChannel? _channel;
  StreamSubscription? _channelSub;
  Timer? _reconnectTimer;
  int _reconnectDelaySeconds = 1;
  bool _disposed = false;

  ConnectionStatus _status = ConnectionStatus.disconnected;
  ConnectionStatus get status => _status;

  // PTT state
  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;

  String? _activeSpeakerId;
  String? get activeSpeakerId => _activeSpeakerId;

  String? _activeSpeakerName;
  String? get activeSpeakerName => _activeSpeakerName;

  bool get isChannelBusy =>
      _activeSpeakerId != null && _activeSpeakerId != userId;

  // Group membership presence
  final List<Member> _members = [];
  List<Member> get members => List.unmodifiable(_members);

  // Audio recording
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<Uint8List>? _recordSub;
  List<int> _audioBuffer = [];

  // Audio playback
  bool _soundInitialized = false;

  WebSocketService({
    required this.groupId,
    required this.userId,
    required this.displayName,
  }) {
    _initAudioPlayer();
    connect();
  }

  Future<void> _initAudioPlayer() async {
    try {
      await FlutterPcmSound.setup(
        sampleRate: AppConfig.sampleRate,
        channelCount: AppConfig.channels,
      );
      _soundInitialized = true;
    } catch (e) {
      debugPrint('Error initializing FlutterPcmSound: $e');
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
    _activeSpeakerId = null;
    _activeSpeakerName = null;
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
        _activeSpeakerId = data['active_speaker_id'] as String?;
        _activeSpeakerName = data['active_speaker_name'] as String?;
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
        if (_activeSpeakerId == uId) {
          _activeSpeakerId = null;
          _activeSpeakerName = null;
        }
        notifyListeners();
        break;

      case 'ptt_started':
        final uId = data['user_id'] as String;
        final dName = data['display_name'] as String?;
        _activeSpeakerId = uId;
        _activeSpeakerName = dName ?? (_members.firstWhere((m) => m.userId == uId, orElse: () => Member(userId: uId, displayName: 'Member')).displayName);
        if (uId == userId) {
          _isSpeaking = true;
        }
        notifyListeners();
        break;

      case 'ptt_stopped':
        final uId = data['user_id'] as String;
        if (_activeSpeakerId == uId) {
          _activeSpeakerId = null;
          _activeSpeakerName = null;
        }
        if (uId == userId) {
          _isSpeaking = false;
        }
        notifyListeners();
        break;

      case 'ptt_rejected':
        // Channel was busy, cancel local speaking state
        _stopRecording();
        _isSpeaking = false;
        notifyListeners();
        break;
    }
  }

  void _playAudioChunk(Uint8List pcmBytes) {
    if (!_soundInitialized || pcmBytes.isEmpty) return;
    try {
      final byteData = pcmBytes.buffer.asByteData(
        pcmBytes.offsetInBytes,
        pcmBytes.lengthInBytes,
      );
      FlutterPcmSound.feed(PcmArrayInt16(bytes: byteData));
    } catch (e) {
      debugPrint('Error feeding audio to FlutterPcmSound: $e');
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

    // 1. Send ptt_start signal
    _channel?.sink.add(jsonEncode({'type': 'ptt_start'}));
    _isSpeaking = true;
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

        // Buffer into 40ms frames (~1280 bytes) before sending over WebSocket
        _audioBuffer.addAll(chunk);
        while (_audioBuffer.length >= AppConfig.frameChunkSize) {
          final frame = _audioBuffer.sublist(0, AppConfig.frameChunkSize);
          _channel?.sink.add(Uint8List.fromList(frame));
          _audioBuffer = _audioBuffer.sublist(AppConfig.frameChunkSize);
        }
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
    await _stopRecording();

    // Flush any remaining buffered audio bytes
    if (_audioBuffer.isNotEmpty) {
      _channel?.sink.add(Uint8List.fromList(_audioBuffer));
      _audioBuffer.clear();
    }

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
