import 'package:flutter/material.dart';
import '../config.dart';
import '../models/group.dart';
import '../services/api_service.dart';
import '../services/user_service.dart';
import '../theme.dart';
import 'create_group_screen.dart';
import 'group_talk_screen.dart';
import 'join_qr_screen.dart';

class GroupsListScreen extends StatefulWidget {
  const GroupsListScreen({super.key});

  @override
  State<GroupsListScreen> createState() => _GroupsListScreenState();
}

class _GroupsListScreenState extends State<GroupsListScreen> {
  List<Group> _groups = [];
  String _displayName = 'Operator';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final name = await UserService.getDisplayName();
      final groups = await ApiService.listGroups();

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
        title: const Text('Edit Callsign / Name'),
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

    if (newName != null && newName.isNotEmpty) {
      await UserService.setDisplayName(newName);
      setState(() => _displayName = newName);
    }
  }

  void _configureServerHost() {
    final controller = TextEditingController(text: AppConfig.effectiveHost);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WalkieTheme.surfaceCardElevated,
        title: const Text('Backend Server IP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set the host IP of your FastAPI backend:',
              style: TextStyle(fontSize: 13, color: WalkieTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: WalkieTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'e.g. 192.168.1.15 or 10.0.2.2',
                hintStyle: TextStyle(color: WalkieTheme.textTertiary),
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
            onPressed: () {
              AppConfig.customHost = controller.text.trim();
              Navigator.of(ctx).pop();
              _loadData();
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: WalkieTheme.primaryAmber,
              ),
            ),
            const SizedBox(width: 8),
            const Text('Walkie Channels'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_ethernet_rounded),
            tooltip: 'Server Config',
            onPressed: _configureServerHost,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // User callsign profile bar
            InkWell(
              onTap: _editDisplayName,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                color: WalkieTheme.surfaceCard,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: WalkieTheme.primaryAmber.withOpacity(0.2),
                      child: const Icon(Icons.person, size: 18, color: WalkieTheme.primaryAmber),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'YOUR CALLSIGN',
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            letterSpacing: 1.2,
                            color: WalkieTheme.textTertiary,
                          ),
                        ),
                        Text(
                          _displayName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: WalkieTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Icon(Icons.edit_outlined, size: 18, color: WalkieTheme.textTertiary),
                  ],
                ),
              ),
            ),

            // Main Channel List Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: WalkieTheme.primaryAmber),
                    )
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.wifi_off_rounded, size: 48, color: WalkieTheme.alertCrimson),
                                const SizedBox(height: 12),
                                Text(
                                  'Cannot reach server\n($_error)',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: WalkieTheme.textSecondary),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadData,
                                  child: const Text('Retry Connection'),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _configureServerHost,
                                  child: const Text('Change Server IP'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _groups.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.radio, size: 56, color: WalkieTheme.textTertiary.withOpacity(0.4)),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No channels found',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: WalkieTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Create a new channel or scan a QR code to join.',
                                    style: TextStyle(fontSize: 13, color: WalkieTheme.textTertiary),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              itemCount: _groups.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (ctx, idx) {
                                final group = _groups[idx];
                                return Card(
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    leading: CircleAvatar(
                                      radius: 22,
                                      backgroundColor: WalkieTheme.surfaceCardElevated,
                                      child: const Icon(Icons.graphic_eq, color: WalkieTheme.primaryAmber),
                                    ),
                                    title: Text(
                                      group.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: WalkieTheme.textPrimary,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'CODE: ${group.joinToken} • ${group.memberCount} members',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                        color: WalkieTheme.textTertiary,
                                      ),
                                    ),
                                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: WalkieTheme.textTertiary),
                                    onTap: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => GroupTalkScreen(group: group),
                                        ),
                                      );
                                      _loadData(); // refresh on return
                                    },
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: WalkieTheme.surfaceCard,
            border: Border(top: BorderSide(color: WalkieTheme.surfaceCardBorder)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                  label: const Text('Scan QR'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: WalkieTheme.textPrimary,
                    side: const BorderSide(color: WalkieTheme.surfaceCardBorder),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const JoinQrScreen()),
                    );
                    _loadData();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Create'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
                    );
                    _loadData();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
