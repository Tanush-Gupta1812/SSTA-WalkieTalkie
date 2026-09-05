import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config.dart';
import '../models/group.dart';
import '../services/api_service.dart';
import '../services/user_service.dart';
import '../services/active_channel_session.dart';
import '../theme.dart';
import 'create_group_screen.dart';
import 'group_talk_screen.dart';
import 'join_qr_screen.dart';
import 'qr_share_screen.dart';

class GroupsListScreen extends StatefulWidget {
  const GroupsListScreen({super.key});

  @override
  State<GroupsListScreen> createState() => _GroupsListScreenState();
}

class _GroupsListScreenState extends State<GroupsListScreen> with SingleTickerProviderStateMixin {
  List<Group> _groups = [];
  String _displayName = 'Operator';
  bool _isLoading = true;
  String? _error;

  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    ActiveChannelSession.instance.addListener(_onSessionUpdate);
    _loadData();
  }

  @override
  void dispose() {
    _radarController.dispose();
    ActiveChannelSession.instance.removeListener(_onSessionUpdate);
    super.dispose();
  }

  void _onSessionUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await AppConfig.ensureConnected();
      final userId = await UserService.getUserId();
      final name = await UserService.getDisplayName();
      final groups = await ApiService.listGroups(userId: userId);

      if (mounted) {
        setState(() {
          _displayName = name;
          _groups = groups;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _editDisplayName() async {
    final controller = TextEditingController(text: _displayName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WalkieTheme.surfaceCardElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.badge_rounded, color: WalkieTheme.primaryAmber, size: 20),
            SizedBox(width: 8),
            Text('Edit Callsign'),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: WalkieTheme.textPrimary, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
            hintText: 'Enter your tactical handle',
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
            child: const Text('Save Callsign'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != _displayName) {
      await UserService.setDisplayName(newName);
      setState(() => _displayName = newName);

      try {
        final userId = await UserService.getUserId();
        await ApiService.updateDisplayName(userId: userId, displayName: newName);
      } catch (e) {
        debugPrint('Failed to sync display name to server: $e');
      }

      ActiveChannelSession.instance.updateDisplayName(newName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            content: Text('Callsign updated to "$newName"'),
          ),
        );
        _loadData();
      }
    }
  }

  Future<void> _showQuickPasscodeDialog() async {
    final controller = TextEditingController();
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: WalkieTheme.surfaceCardElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.pin_rounded, color: WalkieTheme.primaryAmber, size: 22),
              SizedBox(width: 10),
              Text('Enter Passcode'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter the 6-character frequency join code to link with your squad:',
                style: TextStyle(fontSize: 13, color: WalkieTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  color: WalkieTheme.primaryAmber,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. WALK92',
                  hintStyle: TextStyle(
                    color: WalkieTheme.textTertiary.withValues(alpha: 0.5),
                    letterSpacing: 2,
                  ),
                  filled: true,
                  fillColor: WalkieTheme.surfaceCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: WalkieTheme.surfaceCardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: WalkieTheme.primaryAmber, width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: WalkieTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final token = controller.text.trim().toUpperCase();
                      if (token.isEmpty) return;

                      setDialogState(() => isSubmitting = true);
                      try {
                        final userId = await UserService.getUserId();
                        final displayName = await UserService.getDisplayName();
                        final group = await ApiService.joinGroupByToken(
                          joinToken: token,
                          userId: userId,
                          displayName: displayName,
                        );
                        await UserService.saveJoinedGroupId(group.id);

                        if (!context.mounted) return;
                        Navigator.of(ctx).pop();

                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => GroupTalkScreen(group: group),
                          ),
                        );
                        _loadData();
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: WalkieTheme.alertCrimson,
                            content: Text('Failed to join: ${e.toString().replaceAll('Exception: ', '')}'),
                          ),
                        );
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renameGroup(Group group) async {
    final controller = TextEditingController(text: group.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WalkieTheme.surfaceCardElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

    if (newName != null && newName.isNotEmpty && newName != group.name) {
      try {
        await ApiService.renameGroup(groupId: group.id, newName: newName);
        ActiveChannelSession.instance.updateGroupName(group.id, newName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 2),
              content: Text('Channel renamed to "$newName"'),
            ),
          );
          _loadData();
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

  Future<void> _leaveGroup(Group group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WalkieTheme.surfaceCardElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave Channel?'),
        content: Text('Disconnect from "${group.name}"?'),
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
      final userId = await UserService.getUserId();
      await ApiService.leaveGroup(groupId: group.id, userId: userId);
      await UserService.removeJoinedGroupId(group.id);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Left "${group.name}"')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to leave: $e')),
        );
      }
    }
  }

  Future<void> _deleteGroup(Group group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WalkieTheme.surfaceCardElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Channel Permanently?'),
        content: Text(
          'Are you sure you want to delete "${group.name}"? This will permanently delete the channel for all members.',
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
      await ApiService.deleteGroup(group.id);
      await UserService.removeJoinedGroupId(group.id);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "${group.name}" successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: WalkieTheme.readyEmerald,
                boxShadow: [
                  BoxShadow(
                    color: WalkieTheme.readyEmerald.withValues(alpha: 0.8),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Walkie Channels',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: WalkieTheme.readyEmerald.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: WalkieTheme.readyEmerald.withValues(alpha: 0.4)),
              ),
              child: const Text(
                'ARMED',
                style: TextStyle(
                  fontSize: 9,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  color: WalkieTheme.readyEmerald,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.pin_rounded),
            tooltip: 'Enter Passcode',
            onPressed: _showQuickPasscodeDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Channels',
            onPressed: _loadData,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Tactical Telemetry & Operator Header HUD
            _buildTacticalHeaderHud(),

            // Active Channel Sticky Banner (When receiving in background)
            if (ActiveChannelSession.instance.hasActiveSession)
              _buildActiveSessionBanner(),

            // Quick Command Action Tiles (Scan QR, Enter Code, New Channel)
            _buildQuickCommandTiles(),

            // Main Channel List / Radar Viewport
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: WalkieTheme.primaryAmber),
                    )
                  : _error != null
                      ? _buildErrorView()
                      : RefreshIndicator(
                          color: WalkieTheme.primaryAmber,
                          backgroundColor: WalkieTheme.surfaceCardElevated,
                          onRefresh: _loadData,
                          child: _groups.isEmpty
                              ? _buildTacticalEmptyRadarState()
                              : _buildGroupsList(),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tactical Callsign & System Telemetry HUD Card
  Widget _buildTacticalHeaderHud() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: WalkieTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WalkieTheme.surfaceCardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Callsign Profile
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _editDisplayName,
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: WalkieTheme.primaryAmber.withValues(alpha: 0.15),
                        border: Border.all(color: WalkieTheme.primaryAmber.withValues(alpha: 0.5), width: 1.5),
                      ),
                      child: const Icon(Icons.person_rounded, size: 22, color: WalkieTheme.primaryAmber),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: WalkieTheme.readyEmerald,
                          border: Border.all(color: WalkieTheme.surfaceCard, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text(
                          'OPERATOR CALLSIGN',
                          style: TextStyle(
                            fontSize: 9,
                            fontFamily: 'monospace',
                            letterSpacing: 1.2,
                            color: WalkieTheme.textTertiary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.edit, size: 10, color: WalkieTheme.textTertiary),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _displayName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: WalkieTheme.textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          // Hardware Telemetry Badges
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: WalkieTheme.surfaceCardElevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: WalkieTheme.surfaceCardBorder),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.graphic_eq_rounded, size: 11, color: WalkieTheme.readyEmerald),
                    SizedBox(width: 4),
                    Text(
                      '16k PCM',
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: WalkieTheme.readyEmerald,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '0ms DUPLEX PTT',
                style: TextStyle(
                  fontSize: 9,
                  fontFamily: 'monospace',
                  color: WalkieTheme.textTertiary,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Active Channel Sticky Live Radar Banner
  Widget _buildActiveSessionBanner() {
    return InkWell(
      onTap: () {
        final grp = ActiveChannelSession.instance.activeGroup;
        if (grp != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => GroupTalkScreen(group: grp),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: WalkieTheme.readyEmerald.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: WalkieTheme.readyEmerald, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: WalkieTheme.readyEmerald.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: WalkieTheme.readyEmerald,
                boxShadow: [
                  BoxShadow(
                    color: WalkieTheme.readyEmerald.withValues(alpha: 0.9),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TRANSMITTING / RECEIVING (BACKGROUND ACTIVE)',
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: WalkieTheme.readyEmerald,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Frequency: ${ActiveChannelSession.instance.activeGroupName ?? ""}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: WalkieTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: WalkieTheme.readyEmerald,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Text(
                    'ENTER',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.black),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 3 Tactical Action Tiles (Scan QR, Enter Passcode, Create Channel)
  Widget _buildQuickCommandTiles() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        children: [
          // 1. Scan QR Tile
          Expanded(
            child: _buildActionTile(
              title: 'SCAN QR',
              subtitle: 'Camera Sync',
              icon: Icons.qr_code_scanner_rounded,
              color: WalkieTheme.primaryAmber,
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const JoinQrScreen()),
                );
                _loadData();
              },
            ),
          ),
          const SizedBox(width: 10),
          // 2. Enter Passcode Tile
          Expanded(
            child: _buildActionTile(
              title: 'PASSCODE',
              subtitle: 'Direct Join',
              icon: Icons.pin_rounded,
              color: const Color(0xFF38BDF8), // Cyan blue accent
              onTap: _showQuickPasscodeDialog,
            ),
          ),
          const SizedBox(width: 10),
          // 3. Create Channel Tile
          Expanded(
            child: _buildActionTile(
              title: 'NEW CH',
              subtitle: 'Start Squad',
              icon: Icons.add_circle_outline_rounded,
              color: WalkieTheme.readyEmerald,
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
                );
                _loadData();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: WalkieTheme.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 9,
                color: WalkieTheme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Stunning Animated Tactical Radar Visualizer for the Empty State
  Widget _buildTacticalEmptyRadarState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        const SizedBox(height: 10),

        // Animated Radar Screen Widget
        Center(
          child: SizedBox(
            width: 200,
            height: 200,
            child: AnimatedBuilder(
              animation: _radarController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _TacticalRadarPainter(sweepProgress: _radarController.value),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 20),

        const Center(
          child: Text(
            'RADIO TERMINAL IDLE',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: WalkieTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'No active frequencies detected in your comms network.\nInitialize a channel or scan a squad QR to establish a link.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: WalkieTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Primary Action Buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Create Channel'),
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
                  );
                  _loadData();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                label: const Text('Scan Squad QR'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: WalkieTheme.textPrimary,
                  side: const BorderSide(color: WalkieTheme.surfaceCardBorder),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const JoinQrScreen()),
                  );
                  _loadData();
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 28),

        // Tactical Specification Pills
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: WalkieTheme.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: WalkieTheme.surfaceCardBorder),
          ),
          child: const Column(
            children: [
              _TacticalFeatureRow(
                icon: Icons.mic_external_on_rounded,
                title: 'Full-Duplex Audio Engine',
                desc: '16kHz Linear PCM with zero-latency concurrent speaking.',
              ),
              Divider(color: WalkieTheme.surfaceCardBorder, height: 18),
              _TacticalFeatureRow(
                icon: Icons.shield_outlined,
                title: 'Zero Storage RAM Footprint',
                desc: '100% ephemeral audio stream with no server recording buffers.',
              ),
              Divider(color: WalkieTheme.surfaceCardBorder, height: 18),
              _TacticalFeatureRow(
                icon: Icons.volume_up_outlined,
                title: 'Silent Mode Audio Override',
                desc: 'Communication speakerphone routes audio even when phone is silent.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// List of Connected Squad Channels
  Widget _buildGroupsList() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      children: [
        // Section Header with count badge
        Row(
          children: [
            const Text(
              'ACTIVE SQUAD FREQUENCIES',
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: WalkieTheme.textTertiary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: WalkieTheme.primaryAmber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${_groups.length}',
                style: const TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  color: WalkieTheme.primaryAmber,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Channel Cards
        ...List.generate(_groups.length, (idx) {
          final group = _groups[idx];
          final isActiveThisGroup =
              ActiveChannelSession.instance.hasActiveSession &&
              ActiveChannelSession.instance.activeGroupId == group.id;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: WalkieTheme.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActiveThisGroup ? WalkieTheme.readyEmerald : WalkieTheme.surfaceCardBorder,
                width: isActiveThisGroup ? 2.0 : 1.0,
              ),
              boxShadow: isActiveThisGroup
                  ? [
                      BoxShadow(
                        color: WalkieTheme.readyEmerald.withValues(alpha: 0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GroupTalkScreen(group: group),
                    ),
                  );
                  _loadData();
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Channel Icon Avatar
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActiveThisGroup
                                  ? WalkieTheme.readyEmerald.withValues(alpha: 0.2)
                                  : WalkieTheme.surfaceCardElevated,
                              border: Border.all(
                                color: isActiveThisGroup
                                    ? WalkieTheme.readyEmerald
                                    : WalkieTheme.surfaceCardBorder,
                              ),
                            ),
                            child: Icon(
                              isActiveThisGroup ? Icons.graphic_eq_rounded : Icons.radio_rounded,
                              color: isActiveThisGroup ? WalkieTheme.readyEmerald : WalkieTheme.primaryAmber,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        group.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: WalkieTheme.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isActiveThisGroup) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: WalkieTheme.readyEmerald.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: WalkieTheme.readyEmerald, width: 0.8),
                                        ),
                                        child: const Text(
                                          '● LIVE',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.bold,
                                            color: WalkieTheme.readyEmerald,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        Clipboard.setData(ClipboardData(text: group.joinToken));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            duration: const Duration(seconds: 1),
                                            content: Text('Copied code "${group.joinToken}" to clipboard'),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: WalkieTheme.surfaceCardElevated,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'FREQ: ${group.joinToken}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontFamily: 'monospace',
                                                fontWeight: FontWeight.w600,
                                                color: WalkieTheme.primaryAmber,
                                                letterSpacing: 1.0,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(Icons.copy_rounded, size: 10, color: WalkieTheme.textTertiary),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '${group.memberCount} member${group.memberCount == 1 ? "" : "s"}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: WalkieTheme.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Card options popup
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, color: WalkieTheme.textTertiary, size: 20),
                            color: WalkieTheme.surfaceCardElevated,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            onSelected: (val) {
                              if (val == 'share') {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => QrShareScreen(group: group)),
                                );
                              } else if (val == 'rename') {
                                _renameGroup(group);
                              } else if (val == 'leave') {
                                _leaveGroup(group);
                              } else if (val == 'delete') {
                                _deleteGroup(group);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'share',
                                child: Row(
                                  children: [
                                    Icon(Icons.qr_code_rounded, size: 18, color: WalkieTheme.primaryAmber),
                                    SizedBox(width: 8),
                                    Text('Share QR Code'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'rename',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_rounded, size: 18, color: WalkieTheme.textPrimary),
                                    SizedBox(width: 8),
                                    Text('Rename Channel'),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: 'leave',
                                child: Row(
                                  children: [
                                    Icon(Icons.exit_to_app_rounded, size: 18, color: WalkieTheme.textSecondary),
                                    SizedBox(width: 8),
                                    Text('Leave Channel'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_forever_rounded, size: 18, color: WalkieTheme.alertCrimson),
                                    SizedBox(width: 8),
                                    Text('Delete Channel', style: TextStyle(color: WalkieTheme.alertCrimson)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Tune In Quick Button
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isActiveThisGroup
                              ? WalkieTheme.readyEmerald.withValues(alpha: 0.15)
                              : WalkieTheme.surfaceCardElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isActiveThisGroup
                                ? WalkieTheme.readyEmerald.withValues(alpha: 0.5)
                                : WalkieTheme.surfaceCardBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isActiveThisGroup ? Icons.headset_mic_rounded : Icons.cell_tower_rounded,
                              size: 16,
                              color: isActiveThisGroup ? WalkieTheme.readyEmerald : WalkieTheme.primaryAmber,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isActiveThisGroup ? 'ON CHANNEL • TAP TO TALK' : 'TUNE IN TO CHANNEL',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                                color: isActiveThisGroup ? WalkieTheme.readyEmerald : WalkieTheme.primaryAmber,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: WalkieTheme.alertCrimson),
            const SizedBox(height: 12),
            Text(
              'Cannot reach walkie server\n($_error)',
              textAlign: TextAlign.center,
              style: const TextStyle(color: WalkieTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry Connection'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter that renders a live tactical military radar with concentric distance rings, crosshairs, and rotating sweep
class _TacticalRadarPainter extends CustomPainter {
  final double sweepProgress;

  _TacticalRadarPainter({required this.sweepProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = const Color(0xFF0F1512)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // Grid circles
    final ringPaint = Paint()
      ..color = WalkieTheme.readyEmerald.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, radius * 0.33, ringPaint);
    canvas.drawCircle(center, radius * 0.66, ringPaint);
    canvas.drawCircle(center, radius * 0.98, ringPaint);

    // Crosshairs
    final crossPaint = Paint()
      ..color = WalkieTheme.readyEmerald.withValues(alpha: 0.25)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), crossPaint);
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), crossPaint);

    // Rotating sweep gradient
    final sweepAngle = sweepProgress * 2 * math.pi;
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: FractionalOffset.center,
        startAngle: 0.0,
        endAngle: math.pi / 2,
        colors: [
          WalkieTheme.readyEmerald.withValues(alpha: 0.4),
          WalkieTheme.readyEmerald.withValues(alpha: 0.0),
        ],
        transform: GradientRotation(sweepAngle),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius * 0.98, sweepPaint);

    // Outer border glowing ring
    final outerRingPaint = Paint()
      ..color = WalkieTheme.readyEmerald.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius * 0.98, outerRingPaint);

    // Radar blip targets (simulating tactical radio nodes)
    final blipPaint = Paint()
      ..color = WalkieTheme.primaryAmber
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(center.dx + radius * 0.4, center.dy - radius * 0.3), 3.5, blipPaint);
    canvas.drawCircle(Offset(center.dx - radius * 0.5, center.dy + radius * 0.2), 3.0, blipPaint);
  }

  @override
  bool shouldRepaint(covariant _TacticalRadarPainter oldDelegate) =>
      oldDelegate.sweepProgress != sweepProgress;
}

class _TacticalFeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _TacticalFeatureRow({
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: WalkieTheme.primaryAmber, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: WalkieTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 11,
                  color: WalkieTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
