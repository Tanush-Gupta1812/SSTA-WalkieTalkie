import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';
import '../services/user_service.dart';
import '../theme.dart';
import 'group_talk_screen.dart';

class JoinQrScreen extends StatefulWidget {
  const JoinQrScreen({super.key});

  @override
  State<JoinQrScreen> createState() => _JoinQrScreenState();
}

class _JoinQrScreenState extends State<JoinQrScreen> {
  final TextEditingController _codeController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isJoining = false;
  bool _scanned = false;

  @override
  void dispose() {
    _codeController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _joinWithToken(String token) async {
    var cleanToken = token.trim();
    if (cleanToken.contains('token=')) {
      final uri = Uri.tryParse(cleanToken);
      if (uri != null && uri.queryParameters.containsKey('token')) {
        cleanToken = uri.queryParameters['token']!;
      } else if (uri != null && uri.queryParameters.containsKey('join_token')) {
        cleanToken = uri.queryParameters['join_token']!;
      }
    } else if (cleanToken.contains(':')) {
      cleanToken = cleanToken.split(':').last;
    }
    cleanToken = cleanToken.trim().toUpperCase();
    if (cleanToken.isEmpty || _isJoining) return;

    setState(() => _isJoining = true);

    try {
      final userId = await UserService.getUserId();
      final displayName = await UserService.getDisplayName();

      final group = await ApiService.joinGroupByToken(
        joinToken: cleanToken,
        userId: userId,
        displayName: displayName,
      );

      await UserService.saveJoinedGroupId(group.id);

      if (!mounted) return;

      // Replace scanner with talk screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => GroupTalkScreen(group: group),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isJoining = false;
        _scanned = false; // Allow retry
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to join: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: WalkieTheme.alertCrimson,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Channel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _scannerController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Point camera at a channel QR code',
                style: TextStyle(
                  color: WalkieTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),

              // Camera Scanner Viewport
              Container(
                height: 280,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: WalkieTheme.surfaceCardBorder, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    MobileScanner(
                      controller: _scannerController,
                      onDetect: (capture) {
                        if (_scanned || _isJoining) return;
                        final List<Barcode> barcodes = capture.barcodes;
                        for (final barcode in barcodes) {
                          if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
                            _scanned = true;
                            _joinWithToken(barcode.rawValue!);
                            break;
                          }
                        }
                      },
                    ),
                    // Scanner target overlay
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: WalkieTheme.primaryAmber.withValues(alpha: 0.8),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    if (_isJoining)
                      Container(
                        color: Colors.black54,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: WalkieTheme.primaryAmber,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Row(
                children: [
                  Expanded(child: Divider(color: WalkieTheme.surfaceCardBorder)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'OR ENTER PASSCODE',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        letterSpacing: 1.5,
                        color: WalkieTheme.textTertiary,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: WalkieTheme.surfaceCardBorder)),
                ],
              ),
              const SizedBox(height: 20),

              // Manual Code Input
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
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
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: WalkieTheme.surfaceCardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: WalkieTheme.primaryAmber, width: 2),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isJoining
                      ? null
                      : () => _joinWithToken(_codeController.text),
                  child: _isJoining
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Connect Channel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
