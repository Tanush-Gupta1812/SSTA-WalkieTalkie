import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/user_service.dart';
import '../theme.dart';
import 'qr_share_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _isCreating) return;

    setState(() => _isCreating = true);

    try {
      final group = await ApiService.createGroup(name);
      final userId = await UserService.getUserId();
      final displayName = await UserService.getDisplayName();

      // Automatically join newly created group as first member
      await ApiService.joinGroupByToken(
        joinToken: group.joinToken,
        userId: userId,
        displayName: displayName,
      );

      await UserService.saveJoinedGroupId(group.id);

      if (!mounted) return;

      // Navigate to QR share screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => QrShareScreen(group: group),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create channel: $e'),
          backgroundColor: WalkieTheme.alertCrimson,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Channel'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CHANNEL NAME',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  letterSpacing: 1.5,
                  color: WalkieTheme.textTertiary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: WalkieTheme.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. Basecamp Alpha',
                  hintStyle: const TextStyle(color: WalkieTheme.textTertiary),
                  filled: true,
                  fillColor: WalkieTheme.surfaceCard,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: WalkieTheme.surfaceCardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: WalkieTheme.primaryAmber, width: 2),
                  ),
                ),
                onSubmitted: (_) => _create(),
              ),
              const SizedBox(height: 12),
              const Text(
                'A unique join QR code and 6-character passcode will be generated automatically.',
                style: TextStyle(
                  fontSize: 13,
                  color: WalkieTheme.textSecondary,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isCreating ? null : _create,
                  child: _isCreating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Provision Channel'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
