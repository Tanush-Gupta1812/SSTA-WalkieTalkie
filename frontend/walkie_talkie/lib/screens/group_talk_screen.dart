import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/group.dart';
import '../models/member.dart';
import '../services/api_service.dart';
import '../services/user_service.dart';
import '../services/websocket_service.dart';
import '../services/foreground_manager.dart';
import '../services/active_channel_session.dart';
import '../theme.dart';
import 'qr_share_screen.dart';

class GroupTalkScreen extends StatefulWidget {
  final Group group;

  const GroupTalkScreen({super.key, required this.group});

  @override
  State<GroupTalkScreen> createState() => _GroupTalkScreenState();
}

class _GroupTalkScreenState extends State<GroupTalkScreen>
    with SingleTickerProviderStateMixin {
  WebSocketService? _wsService;
  String _userId = '';
  String _displayName = '';
  late String _channelName;
  bool _isLoading = true;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _channelName = widget.group.name;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initSession();
  }

  Future<void> _initSession() async {
    // Request microphone and notification permissions on entering talk screen
    await Permission.microphone.request();
    await ForegroundManager.requestPermission();

    _userId = await UserService.getUserId();
    _displayName = await UserService.getDisplayName();

    _wsService = ActiveChannelSession.instance.getOrCreateSession(
      group: widget.group,
      userId: _userId,
      displayName: _displayName,
    );

    _wsService!.addListener(_onWsUpdate);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _onWsUpdate() {
    if (!mounted) return;
    if (_wsService?.isGroupDeleted == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This channel has been deleted by an administrator.')),
      );
      Navigator.of(context).pop();
      return;
    }

    if (ActiveChannelSession.instance.activeGroupName != null &&
        ActiveChannelSession.instance.activeGroupName != _channelName) {
      _channelName = ActiveChannelSession.instance.activeGroupName!;
    }

    setState(() {});
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _wsService?.removeListener(_onWsUpdate);
    // Note: Do NOT dispose _wsService or ForegroundManager here!
    // ActiveChannelSession maintains the persistent audio session across pages
    super.dispose();
  }

  Future<void> _renameChannel() async {
    final controller = TextEditingController(text: _channelName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WalkieTheme.surfaceCardElevated,
        title: const Text('Rename Channel'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: WalkieTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Enter new channel name',
            hintStyle: TextStyle(color: WalkieTheme.textTertiary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel', style: TextStyle(color: WalkieTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != _channelName) {
      try {
        await ApiService.renameGroup(groupId: widget.group.id, newName: newName);
        ActiveChannelSession.instance.updateGroupName(widget.group.id, newName);
        setState(() => _channelName = newName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 2),
              content: Text('Channel renamed to "$newName"'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: WalkieTheme.alertCrimson,
              content: Text('Failed to rename: $e'),
            ),
          );
        }
      }
    }
  }

  Future<void> _editMyCallsign() async {
    final controller = TextEditingController(text: _displayName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WalkieTheme.surfaceCardElevated,
        title: const Text('Edit My Callsign'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: WalkieTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Enter your callsign',
            hintStyle: TextStyle(color: WalkieTheme.textTertiary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel', style: TextStyle(color: WalkieTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != _displayName) {
      await UserService.setDisplayName(newName);
      setState(() => _displayName = newName);

      try {
        await ApiService.updateDisplayName(userId: _userId, displayName: newName);
      } catch (e) {
        debugPrint('Failed to sync display name to server: $e');
      }

      _wsService?.updateDisplayName(newName);
      ActiveChannelSession.instance.updateDisplayName(newName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            content: Text('Callsign changed to "$newName"'),
          ),
        );
      }
    }
  }

  Future<void> _leaveChannel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WalkieTheme.surfaceCardElevated,
        title: const Text('Leave Channel?'),
        content: Text('Are you sure you want to disconnect from "${widget.group.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: WalkieTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: WalkieTheme.alertCrimson,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      ActiveChannelSession.instance.disconnect();
      await ApiService.leaveGroup(groupId: widget.group.id, userId: _userId);
      await UserService.removeJoinedGroupId(widget.group.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to leave: $e')),
        );
      }
    }
  }

  Future<void> _deleteChannel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WalkieTheme.surfaceCardElevated,
        title: const Text('Delete Channel Permanently?'),
        content: Text(
          'Are you sure you want to delete "${widget.group.name}"? This will disconnect all members and remove it from the server.',
          style: const TextStyle(color: WalkieTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: WalkieTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: WalkieTheme.alertCrimson,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Channel'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      ActiveChannelSession.instance.disconnect();
      await ApiService.deleteGroup(widget.group.id);
      await UserService.removeJoinedGroupId(widget.group.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Channel deleted successfully')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete channel: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _wsService == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: WalkieTheme.primaryAmber),
        ),
      );
    }

    final isTransmitting = _wsService!.isSpeaking || _wsService!.wantsToSpeak;
    final otherSpeakers = _wsService!.otherActiveSpeakerNames;
    final isConnected = _wsService!.status == ConnectionStatus.connected;
    final isConnecting = _wsService!.status == ConnectionStatus.connecting;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_channelName),
            Text(
              '${_wsService!.members.where((m) => m.isOnline).length} ONLINE',
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: WalkieTheme.readyEmerald,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        actions: [
          // Tactical Power Toggle (Standby / Online)
          Tooltip(
            message: _wsService!.isPoweredOn
                ? 'Channel Power: ON (Receiving in background)'
                : 'Channel Power: OFF (Standby)',
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                _wsService!.togglePower();
                if (_wsService!.isPoweredOn) {
                  UserService.saveActiveGroup(widget.group);
                  ForegroundManager.start(
                    channelName: widget.group.name,
                    userName: _displayName,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      duration: Duration(seconds: 2),
                      content: Text('📻 Power ON: Connected & listening in background.'),
                    ),
                  );
                } else {
                  UserService.clearActiveGroup();
                  ForegroundManager.stop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      duration: Duration(seconds: 2),
                      content: Text('🔴 Power OFF: Disconnected from channel.'),
                    ),
                  );
                }
                setState(() {});
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _wsService!.isPoweredOn
                            ? WalkieTheme.readyEmerald
                            : WalkieTheme.alertCrimson,
                        boxShadow: [
                          BoxShadow(
                            color: (_wsService!.isPoweredOn
                                    ? WalkieTheme.readyEmerald
                                    : WalkieTheme.alertCrimson)
                                .withValues(alpha: 0.8),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.power_settings_new_rounded,
                      size: 22,
                      color: _wsService!.isPoweredOn
                          ? WalkieTheme.readyEmerald
                          : WalkieTheme.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              _wsService!.echoMode ? Icons.repeat_on_rounded : Icons.repeat_rounded,
              color: _wsService!.echoMode ? WalkieTheme.primaryAmber : WalkieTheme.textSecondary,
            ),
            tooltip: _wsService!.echoMode ? 'Echo Test: ON (Hearing Yourself)' : 'Echo Test: OFF',
            onPressed: () {
              setState(() {
                _wsService!.echoMode = !_wsService!.echoMode;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 2),
                  content: Text(
                    _wsService!.echoMode
                        ? 'Echo Test ON: Speak to hear your own voice relayed from the server.'
                        : 'Echo Test OFF: Normal mode (others hear you).',
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_rounded),
            tooltip: 'Share QR Code',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => QrShareScreen(group: widget.group),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'rename') _renameChannel();
              if (val == 'edit_name') _editMyCallsign();
              if (val == 'leave') _leaveChannel();
              if (val == 'delete') _deleteChannel();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, color: WalkieTheme.textPrimary, size: 20),
                    SizedBox(width: 8),
                    Text('Rename Channel'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'edit_name',
                child: Row(
                  children: [
                    Icon(Icons.badge_rounded, color: WalkieTheme.textPrimary, size: 20),
                    SizedBox(width: 8),
                    Text('Edit My Callsign'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'leave',
                child: Row(
                  children: [
                    Icon(Icons.exit_to_app, color: WalkieTheme.textPrimary, size: 20),
                    SizedBox(width: 8),
                    Text('Leave Channel'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever_rounded, color: WalkieTheme.alertCrimson, size: 20),
                    SizedBox(width: 8),
                    Text('Delete Channel', style: TextStyle(color: WalkieTheme.alertCrimson)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Connection status warning banner
            if (!isConnected)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: isConnecting
                    ? WalkieTheme.primaryAmber.withValues(alpha: 0.2)
                    : WalkieTheme.alertCrimson.withValues(alpha: 0.2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isConnecting ? Icons.sync : Icons.cloud_off,
                      size: 16,
                      color: isConnecting ? WalkieTheme.primaryAmber : WalkieTheme.alertCrimson,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isConnecting ? 'Connecting to channel...' : 'Disconnected. Reconnecting...',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isConnecting ? WalkieTheme.primaryAmber : WalkieTheme.alertCrimson,
                      ),
                    ),
                  ],
                ),
              ),

            // 2. Active Channel Members List Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: WalkieTheme.surfaceCard,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MEMBERS IN FREQUENCY',
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      letterSpacing: 1.5,
                      color: WalkieTheme.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 52,
                    child: _wsService!.members.isEmpty
                        ? const Center(
                            child: Text(
                              'You are the only member connected',
                              style: TextStyle(fontSize: 12, color: WalkieTheme.textTertiary),
                            ),
                          )
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _wsService!.members.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 12),
                            itemBuilder: (ctx, idx) {
                              final member = _wsService!.members[idx];
                              final isUserSpeaking =
                                  _wsService!.activeSpeakerIds.contains(member.userId);

                              return _buildMemberBadge(member, isUserSpeaking);
                            },
                          ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // 3. Status readout display
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  if (isTransmitting) ...[
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.mic, color: WalkieTheme.primaryAmber, size: 20),
                        SizedBox(width: 6),
                        Text(
                          'TRANSMITTING...',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            color: WalkieTheme.primaryAmber,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      otherSpeakers.isNotEmpty
                          ? 'Also transmitting with ${otherSpeakers.join(", ")}'
                          : 'Release button to stop transmission',
                      style: const TextStyle(fontSize: 13, color: WalkieTheme.textSecondary),
                    ),
                  ] else if (otherSpeakers.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.volume_up, color: WalkieTheme.readyEmerald, size: 20),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            otherSpeakers.length == 1
                                ? '${otherSpeakers.first.toUpperCase()} IS SPEAKING'
                                : '${otherSpeakers.join(", ").toUpperCase()} ARE SPEAKING',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: WalkieTheme.readyEmerald,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Multi-talk active • Hold button to join & speak',
                      style: TextStyle(fontSize: 13, color: WalkieTheme.readyEmerald),
                    ),
                  ] else ...[
                    const Text(
                      'READY',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: WalkieTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Press and hold to transmit voice',
                      style: TextStyle(fontSize: 13, color: WalkieTheme.textTertiary),
                    ),
                  ],
                ],
              ),
            ),

            if (_wsService!.echoMode)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: WalkieTheme.primaryAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: WalkieTheme.primaryAmber.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.repeat_rounded, size: 14, color: WalkieTheme.primaryAmber),
                    SizedBox(width: 6),
                    Text(
                      'ECHO TEST ACTIVE (Hearing Yourself)',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: WalkieTheme.primaryAmber,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // 4. Large Push-To-Talk Button (Instant 0ms hardware touch reaction via Listener)
            Center(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) {
                  if (isConnected && _wsService!.isPoweredOn) {
                    HapticFeedback.heavyImpact();
                    _wsService!.startPTT();
                  } else {
                    HapticFeedback.vibrate();
                  }
                },
                onPointerUp: (_) {
                  HapticFeedback.lightImpact();
                  _wsService!.stopPTT();
                },
                onPointerCancel: (_) {
                  _wsService!.stopPTT();
                },
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    final scale = isTransmitting
                        ? (1.0 + (_wsService!.micLevel * 0.15) + (_pulseAnimation.value - 1.0))
                        : 1.0;
                    return Transform.scale(
                      scale: scale,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isTransmitting
                          ? WalkieTheme.primaryAmber
                          : WalkieTheme.surfaceCardElevated,
                      border: Border.all(
                        color: isTransmitting
                            ? WalkieTheme.primaryAmberLight
                            : (otherSpeakers.isNotEmpty
                                ? WalkieTheme.readyEmerald.withValues(alpha: 0.8)
                                : WalkieTheme.surfaceCardBorder),
                        width: isTransmitting ? 4 : (otherSpeakers.isNotEmpty ? 3 : 2),
                      ),
                      boxShadow: [
                        if (isTransmitting)
                          BoxShadow(
                            color: WalkieTheme.primaryAmber.withValues(alpha: 0.45),
                            blurRadius: 36,
                            spreadRadius: 8,
                          ),
                        if (otherSpeakers.isNotEmpty)
                          BoxShadow(
                            color: WalkieTheme.readyEmerald.withValues(alpha: 0.3),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isTransmitting
                              ? Icons.mic
                              : (otherSpeakers.isNotEmpty ? Icons.record_voice_over : Icons.mic_none),
                          size: 56,
                          color: isTransmitting
                              ? const Color(0xFF472A00)
                              : (otherSpeakers.isNotEmpty
                                  ? WalkieTheme.readyEmerald
                                  : WalkieTheme.textPrimary),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isTransmitting
                              ? 'TALKING'
                              : (otherSpeakers.isNotEmpty ? 'JOIN TALK' : 'HOLD TO TALK'),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: isTransmitting
                                ? const Color(0xFF472A00)
                                : (otherSpeakers.isNotEmpty
                                    ? WalkieTheme.readyEmerald
                                    : WalkieTheme.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Live Audio Transmission & Reception Status
            if (isTransmitting)
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: WalkieTheme.alertCrimson,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'LIVE STREAMING • ${_wsService!.packetsSent} FRAMES SENT',
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: WalkieTheme.primaryAmber,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Mic level meter
                  Container(
                    width: 140,
                    height: 5,
                    decoration: BoxDecoration(
                      color: WalkieTheme.surfaceCard,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    alignment: Alignment.centerLeft,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 60),
                      width: (140 * (_wsService!.micLevel * 3.0).clamp(0.08, 1.0)),
                      decoration: BoxDecoration(
                        color: WalkieTheme.primaryAmber,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              )
            else if (otherSpeakers.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.volume_up, size: 16, color: WalkieTheme.readyEmerald),
                  const SizedBox(width: 6),
                  Text(
                    'RECEIVING AUDIO • ${_wsService!.packetsReceived} FRAMES',
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: WalkieTheme.readyEmerald,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),

            const Spacer(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberBadge(Member member, bool isUserSpeaking) {
    final initials = member.displayName.isNotEmpty
        ? member.displayName.substring(0, 1).toUpperCase()
        : 'U';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isUserSpeaking
            ? WalkieTheme.primaryAmber.withValues(alpha: 0.2)
            : WalkieTheme.surfaceLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUserSpeaking
              ? WalkieTheme.primaryAmber
              : WalkieTheme.surfaceCardBorder,
          width: isUserSpeaking ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: isUserSpeaking
                ? WalkieTheme.primaryAmber
                : WalkieTheme.surfaceCardElevated,
            child: Text(
              initials,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isUserSpeaking ? Colors.black : WalkieTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                member.displayName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: WalkieTheme.textPrimary,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: member.isOnline
                          ? WalkieTheme.readyEmerald
                          : WalkieTheme.textTertiary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isUserSpeaking
                        ? 'TALKING'
                        : (member.isOnline ? 'ONLINE' : 'OFFLINE'),
                    style: TextStyle(
                      fontSize: 9,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w500,
                      color: isUserSpeaking
                          ? WalkieTheme.primaryAmber
                          : (member.isOnline
                              ? WalkieTheme.readyEmerald
                              : WalkieTheme.textTertiary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
