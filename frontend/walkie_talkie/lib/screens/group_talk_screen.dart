import 'dart:math' as math;
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
    with TickerProviderStateMixin {
  WebSocketService? _wsService;
  String _userId = '';
  String _displayName = '';
  late String _channelName;
  bool _isLoading = true;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _channelName = widget.group.name;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

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
    _waveController.dispose();
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
            // 1. Connection status warning banner (if offline)
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
                      isConnecting ? 'Connecting to frequency...' : 'Disconnected. Reconnecting...',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isConnecting ? WalkieTheme.primaryAmber : WalkieTheme.alertCrimson,
                      ),
                    ),
                  ],
                ),
              ),

            // 2. Tactical Frequency & Hardware Telemetry Sub-header
            _buildFrequencySubHeader(),

            // 3. Squad Frequency Members Card
            _buildSquadPresenceCard(isTransmitting),

            // 4. Center Tactical Audio LCD HUD (Compact Telemetry & Spectrum Display)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
              child: _buildTacticalAudioHud(isTransmitting, otherSpeakers),
            ),

            // 5. Heavy-Duty Tactical Push-To-Talk Button (Expanded thumb zone)
            Expanded(
              child: Center(
                child: _buildPttButton(isTransmitting, otherSpeakers, isConnected),
              ),
            ),

            // 6. Bottom Tactical Utility Controls Dock
            _buildBottomUtilityDock(),
          ],
        ),
      ),
    );
  }

  /// Tactical Frequency & Comms Specs Sub-header
  Widget _buildFrequencySubHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: WalkieTheme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WalkieTheme.surfaceCardBorder),
      ),
      child: Row(
        children: [
          // Tap to copy frequency code
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () {
              Clipboard.setData(ClipboardData(text: widget.group.joinToken));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 1),
                  content: Text('Copied Frequency Code "${widget.group.joinToken}" to clipboard'),
                ),
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.tag_rounded, size: 14, color: WalkieTheme.primaryAmber),
                const SizedBox(width: 4),
                Text(
                  'FREQ: ${widget.group.joinToken}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: WalkieTheme.primaryAmber,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.copy_rounded, size: 10, color: WalkieTheme.textTertiary),
              ],
            ),
          ),
          const Spacer(),
          // Mode Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: WalkieTheme.readyEmerald.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: WalkieTheme.readyEmerald.withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.volume_up_rounded, size: 10, color: WalkieTheme.readyEmerald),
                SizedBox(width: 4),
                Text(
                  'SPEAKERPHONE ON',
                  style: TextStyle(
                    fontSize: 9,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: WalkieTheme.readyEmerald,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Squad Presence Card (Shows operators in frequency or quick squad invite button)
  Widget _buildSquadPresenceCard(bool isTransmitting) {
    final members = _wsService!.members;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: WalkieTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WalkieTheme.surfaceCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'SQUAD COMMS FREQUENCY',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: WalkieTheme.textTertiary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: WalkieTheme.readyEmerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${members.where((m) => m.isOnline).length} ONLINE',
                  style: const TextStyle(
                    fontSize: 9,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: WalkieTheme.readyEmerald,
                  ),
                ),
              ),
              const Spacer(),
              // Quick share QR shortcut
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => QrShareScreen(group: widget.group),
                    ),
                  );
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_rounded, size: 14, color: WalkieTheme.primaryAmber),
                    SizedBox(width: 4),
                    Text(
                      'INVITE',
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        color: WalkieTheme.primaryAmber,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: members.isEmpty
                ? const Center(
                    child: Text(
                      'Connecting to squad radio network...',
                      style: TextStyle(fontSize: 12, color: WalkieTheme.textTertiary),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: members.length + (members.length <= 1 ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (ctx, idx) {
                      if (idx == members.length && members.length <= 1) {
                        // Helpful Quick Invite squad pill so screen never feels deserted
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => QrShareScreen(group: widget.group),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: WalkieTheme.surfaceCardElevated,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: WalkieTheme.primaryAmber.withValues(alpha: 0.4),
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.group_add_rounded, size: 16, color: WalkieTheme.primaryAmber),
                                SizedBox(width: 6),
                                Text(
                                  'Invite Squad Member',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: WalkieTheme.primaryAmber,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final member = members[idx];
                      final isMemberSpeaking =
                          _wsService!.activeSpeakerIds.contains(member.userId);
                      return _buildMemberBadge(member, isMemberSpeaking);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Center Tactical Cyberpunk Audio LCD HUD (Spacious & Prominent)
  Widget _buildTacticalAudioHud(bool isTransmitting, List<String> otherSpeakers) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0F12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isTransmitting
              ? WalkieTheme.primaryAmber.withValues(alpha: 0.65)
              : (otherSpeakers.isNotEmpty
                  ? WalkieTheme.readyEmerald.withValues(alpha: 0.65)
                  : WalkieTheme.surfaceCardBorder),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isTransmitting
                ? WalkieTheme.primaryAmber.withValues(alpha: 0.15)
                : (otherSpeakers.isNotEmpty
                    ? WalkieTheme.readyEmerald.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.3)),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: LCD Telemetry Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isTransmitting
                          ? WalkieTheme.primaryAmber
                          : (otherSpeakers.isNotEmpty
                              ? WalkieTheme.readyEmerald
                              : WalkieTheme.textTertiary),
                      boxShadow: [
                        if (isTransmitting || otherSpeakers.isNotEmpty)
                          BoxShadow(
                            color: (isTransmitting ? WalkieTheme.primaryAmber : WalkieTheme.readyEmerald)
                                .withValues(alpha: 0.85),
                            blurRadius: 6,
                            spreadRadius: 1.5,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isTransmitting
                        ? 'TX ACTIVE // 16k PCM DUPLEX'
                        : (otherSpeakers.isNotEmpty ? 'RX ACTIVE // INCOMING VOICE' : 'RADIO MONITOR // READY'),
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: isTransmitting
                          ? WalkieTheme.primaryAmber
                          : (otherSpeakers.isNotEmpty
                              ? WalkieTheme.readyEmerald
                              : WalkieTheme.textSecondary),
                    ),
                  ),
                ],
              ),
              Text(
                'GAIN: ${_wsService!.audioGain}x',
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: WalkieTheme.textTertiary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Row 2: Large Animated 75px Audio Frequency Spectrum Analyzer
          SizedBox(
            height: 75,
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, _) {
                return CustomPaint(
                  size: const Size(double.infinity, 75),
                  painter: _TacticalAudioSpectrumPainter(
                    progress: _waveController.value,
                    isTransmitting: isTransmitting,
                    isReceiving: otherSpeakers.isNotEmpty,
                    micLevel: _wsService!.micLevel,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Row 3: Status Readout Banner
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isTransmitting) ...[
                const Text(
                  'TRANSMITTING VOICE TO SQUAD',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.4,
                    color: WalkieTheme.primaryAmber,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mic Amplitude: ${(_wsService!.micLevel * 100).toInt()}% • Release to end',
                  style: const TextStyle(fontSize: 11, color: WalkieTheme.textSecondary),
                ),
              ] else if (otherSpeakers.isNotEmpty) ...[
                Text(
                  '${otherSpeakers.join(", ").toUpperCase()} IS SPEAKING',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.4,
                    color: WalkieTheme.readyEmerald,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Multi-talk full duplex • Hold button to join talk',
                  style: TextStyle(fontSize: 11, color: WalkieTheme.readyEmerald),
                ),
              ] else ...[
                const Text(
                  'FREQUENCY OPEN // STANDBY',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.4,
                    color: WalkieTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Press and hold the PTT button below to talk',
                  style: TextStyle(fontSize: 11, color: WalkieTheme.textTertiary),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Heavy-Duty Tactical Push-To-Talk Button
  Widget _buildPttButton(bool isTransmitting, List<String> otherSpeakers, bool isConnected) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Center(
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
                  ? (1.0 + (_wsService!.micLevel * 0.12) + (_pulseAnimation.value - 1.0) * 0.5)
                  : 1.0;
              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF16181C),
                border: Border.all(
                  color: isTransmitting
                      ? WalkieTheme.primaryAmberLight
                      : (otherSpeakers.isNotEmpty
                          ? WalkieTheme.readyEmerald
                          : WalkieTheme.surfaceCardBorder),
                  width: isTransmitting ? 4 : 2.5,
                ),
                boxShadow: [
                  if (isTransmitting)
                    BoxShadow(
                      color: WalkieTheme.primaryAmber.withValues(alpha: 0.5),
                      blurRadius: 44,
                      spreadRadius: 10,
                    ),
                  if (otherSpeakers.isNotEmpty)
                    BoxShadow(
                      color: WalkieTheme.readyEmerald.withValues(alpha: 0.35),
                      blurRadius: 32,
                      spreadRadius: 6,
                    ),
                ],
              ),
              child: Center(
                // Inner Tactile Ring
                child: Container(
                  width: 205,
                  height: 205,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isTransmitting
                        ? WalkieTheme.primaryAmber
                        : (otherSpeakers.isNotEmpty
                            ? WalkieTheme.surfaceCardElevated
                            : WalkieTheme.surfaceCard),
                    border: Border.all(
                      color: isTransmitting
                          ? WalkieTheme.primaryAmberLight
                          : WalkieTheme.surfaceCardBorder,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isTransmitting
                            ? Icons.mic_rounded
                            : (otherSpeakers.isNotEmpty ? Icons.record_voice_over_rounded : Icons.mic_none_rounded),
                        size: 64,
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
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
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
        ),
      ),
    );
  }

  /// Bottom Tactical Controls Utility Dock
  Widget _buildBottomUtilityDock() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: WalkieTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WalkieTheme.surfaceCardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Audio Gain Booster
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              setState(() {
                if (_wsService!.audioGain == 2.5) {
                  _wsService!.audioGain = 3.5;
                } else if (_wsService!.audioGain == 3.5) {
                  _wsService!.audioGain = 1.5;
                } else {
                  _wsService!.audioGain = 2.5;
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 1),
                  content: Text('Audio Booster Gain set to ${_wsService!.audioGain}x'),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.volume_up_rounded, size: 20, color: WalkieTheme.primaryAmber),
                  const SizedBox(height: 2),
                  Text(
                    'GAIN ${_wsService!.audioGain}x',
                    style: const TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: WalkieTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(width: 1, height: 24, color: WalkieTheme.surfaceCardBorder),
          // Echo Loopback Test
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              setState(() {
                _wsService!.echoMode = !_wsService!.echoMode;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 2),
                  content: Text(
                    _wsService!.echoMode
                        ? 'Echo Test ON: Speak to hear yourself relayed from server.'
                        : 'Echo Test OFF: Normal squad broadcast.',
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _wsService!.echoMode ? Icons.repeat_on_rounded : Icons.repeat_rounded,
                    size: 20,
                    color: _wsService!.echoMode ? WalkieTheme.primaryAmber : WalkieTheme.textTertiary,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _wsService!.echoMode ? 'ECHO: ON' : 'ECHO: OFF',
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: _wsService!.echoMode ? WalkieTheme.primaryAmber : WalkieTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(width: 1, height: 24, color: WalkieTheme.surfaceCardBorder),
          // Share QR Code
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => QrShareScreen(group: widget.group),
                ),
              );
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_rounded, size: 20, color: WalkieTheme.readyEmerald),
                  SizedBox(height: 2),
                  Text(
                    'SHARE QR',
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: WalkieTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
            : WalkieTheme.surfaceCardElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUserSpeaking
              ? WalkieTheme.primaryAmber
              : (member.isOnline ? WalkieTheme.readyEmerald.withValues(alpha: 0.5) : WalkieTheme.surfaceCardBorder),
          width: isUserSpeaking ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: isUserSpeaking
                ? WalkieTheme.primaryAmber
                : WalkieTheme.surfaceLowest,
            child: Text(
              initials,
              style: TextStyle(
                fontSize: 11,
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
                      fontWeight: FontWeight.bold,
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

/// Custom Canvas Painter that renders animated dynamic audio frequency spectrum bars
class _TacticalAudioSpectrumPainter extends CustomPainter {
  final double progress;
  final bool isTransmitting;
  final bool isReceiving;
  final double micLevel;

  _TacticalAudioSpectrumPainter({
    required this.progress,
    required this.isTransmitting,
    required this.isReceiving,
    required this.micLevel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const int barCount = 28;
    final double barWidth = (size.width / barCount) - 3;
    final double centerY = size.height / 2;

    final Color primaryColor = isTransmitting
        ? WalkieTheme.primaryAmber
        : (isReceiving ? WalkieTheme.readyEmerald : WalkieTheme.readyEmerald.withValues(alpha: 0.4));

    final paint = Paint()
      ..color = primaryColor
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.fill;

    for (int i = 0; i < barCount; i++) {
      final double x = i * (barWidth + 3) + barWidth / 2;
      double heightFactor;

      if (isTransmitting) {
        // High energetic waveform reacting to microphone level and phase
        final phase = (progress * 2 * math.pi) + (i * 0.4);
        final dynamicBoost = (micLevel * 1.5).clamp(0.1, 1.0);
        heightFactor = (0.2 + (0.8 * (math.sin(phase).abs())) * dynamicBoost);
      } else if (isReceiving) {
        // Rhythmic pulsing incoming voice waveform
        final phase = (progress * 2 * math.pi) + (i * 0.35);
        heightFactor = 0.25 + 0.7 * math.sin(phase).abs();
      } else {
        // Calm breathing idle radar waveform
        final phase = (progress * 2 * math.pi) + (i * 0.2);
        heightFactor = 0.08 + 0.12 * math.sin(phase).abs();
      }

      final double barHeight = (size.height * heightFactor).clamp(4.0, size.height);
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, centerY), width: barWidth, height: barHeight),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TacticalAudioSpectrumPainter oldDelegate) => true;
}

