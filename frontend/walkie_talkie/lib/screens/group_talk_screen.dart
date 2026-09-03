import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/group.dart';
import '../models/member.dart';
import '../services/api_service.dart';
import '../services/user_service.dart';
import '../services/websocket_service.dart';
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
  bool _isLoading = true;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
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
    // Request microphone permission on entering talk screen
    await Permission.microphone.request();

    _userId = await UserService.getUserId();
    _displayName = await UserService.getDisplayName();

    _wsService = WebSocketService(
      groupId: widget.group.id,
      userId: _userId,
      displayName: _displayName,
    );

    _wsService!.addListener(_onWsUpdate);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _onWsUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _wsService?.removeListener(_onWsUpdate);
    _wsService?.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _wsService == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: WalkieTheme.primaryAmber),
        ),
      );
    }

    final isTransmitting = _wsService!.isSpeaking;
    final isBusy = _wsService!.isChannelBusy;
    final speakerName = _wsService!.activeSpeakerName;
    final isConnected = _wsService!.status == ConnectionStatus.connected;
    final isConnecting = _wsService!.status == ConnectionStatus.connecting;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.group.name),
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
              if (val == 'leave') _leaveChannel();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'leave',
                child: Row(
                  children: [
                    Icon(Icons.exit_to_app, color: WalkieTheme.alertCrimson, size: 20),
                    SizedBox(width: 8),
                    Text('Leave Channel', style: TextStyle(color: WalkieTheme.alertCrimson)),
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
                    ? WalkieTheme.primaryAmber.withOpacity(0.2)
                    : WalkieTheme.alertCrimson.withOpacity(0.2),
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
                            separatorBuilder: (_, __) => const SizedBox(width: 12),
                            itemBuilder: (ctx, idx) {
                              final member = _wsService!.members[idx];
                              final isUserSpeaking =
                                  _wsService!.activeSpeakerId == member.userId;

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
                    const Text(
                      'Release button to stop transmission',
                      style: TextStyle(fontSize: 13, color: WalkieTheme.textSecondary),
                    ),
                  ] else if (isBusy) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.volume_up, color: WalkieTheme.readyEmerald, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          '${speakerName?.toUpperCase() ?? "SOMEONE"} IS SPEAKING',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: WalkieTheme.readyEmerald,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Channel busy • Wait for speaker to finish',
                      style: TextStyle(fontSize: 13, color: WalkieTheme.textTertiary),
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

            const SizedBox(height: 36),

            // 4. Large Push-To-Talk Button
            Center(
              child: GestureDetector(
                onLongPressStart: (_) {
                  if (isConnected && !isBusy) {
                    HapticFeedback.heavyImpact();
                    _wsService!.startPTT();
                  } else {
                    HapticFeedback.vibrate();
                  }
                },
                onLongPressEnd: (_) {
                  if (_wsService!.isSpeaking) {
                    HapticFeedback.lightImpact();
                    _wsService!.stopPTT();
                  }
                },
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: isTransmitting ? _pulseAnimation.value : 1.0,
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
                          : (isBusy
                              ? WalkieTheme.surfaceCard
                              : WalkieTheme.surfaceCardElevated),
                      border: Border.all(
                        color: isTransmitting
                            ? WalkieTheme.primaryAmberLight
                            : (isBusy
                                ? WalkieTheme.alertCrimson.withOpacity(0.5)
                                : WalkieTheme.surfaceCardBorder),
                        width: isTransmitting ? 4 : 2,
                      ),
                      boxShadow: [
                        if (isTransmitting)
                          BoxShadow(
                            color: WalkieTheme.primaryAmber.withOpacity(0.4),
                            blurRadius: 36,
                            spreadRadius: 8,
                          ),
                        if (isBusy)
                          BoxShadow(
                            color: WalkieTheme.readyEmerald.withOpacity(0.2),
                            blurRadius: 20,
                          ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isTransmitting
                              ? Icons.mic
                              : (isBusy ? Icons.volume_up : Icons.mic_none),
                          size: 56,
                          color: isTransmitting
                              ? const Color(0xFF472A00)
                              : (isBusy
                                  ? WalkieTheme.readyEmerald
                                  : WalkieTheme.textPrimary),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isTransmitting
                              ? 'TALKING'
                              : (isBusy ? 'BUSY' : 'HOLD TO TALK'),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: isTransmitting
                                ? const Color(0xFF472A00)
                                : (isBusy
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
            ? WalkieTheme.primaryAmber.withOpacity(0.2)
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
