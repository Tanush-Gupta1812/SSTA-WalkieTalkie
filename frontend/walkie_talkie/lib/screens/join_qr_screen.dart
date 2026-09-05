import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import '../services/user_service.dart';
import '../theme.dart';
import 'group_talk_screen.dart';

class JoinQrScreen extends StatefulWidget {
  const JoinQrScreen({super.key});

  @override
  State<JoinQrScreen> createState() => _JoinQrScreenState();
}

class _JoinQrScreenState extends State<JoinQrScreen> with WidgetsBindingObserver {
  final TextEditingController _codeController = TextEditingController();
  late final MobileScannerController _scannerController;

  bool _isJoining = false;
  bool _scanned = false;
  bool _hasPermission = true;
  bool _isCameraStarting = false;
  String? _cameraErrorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _scannerController = MobileScannerController(
      autoStart: false, // Start manually after lifecycle & permissions are ready
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startCamera();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _codeController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startCamera();
    } else if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _scannerController.stop();
    }
  }

  Future<void> _startCamera() async {
    if (_isCameraStarting || !mounted) return;

    setState(() {
      _isCameraStarting = true;
      _cameraErrorMessage = null;
    });

    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          setState(() {
            _hasPermission = false;
            _isCameraStarting = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() => _hasPermission = true);
      }

      // Stop first to reset any internal controller error state (e.g. permissionDenied)
      await _scannerController.stop();
      await Future.delayed(const Duration(milliseconds: 150));

      if (mounted) {
        await _scannerController.start();
      }
    } catch (e) {
      debugPrint('Error starting camera: $e');
      if (mounted) {
        setState(() {
          _cameraErrorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isCameraStarting = false);
      }
    }
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
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reload Camera',
            onPressed: _startCamera,
          ),
          IconButton(
            icon: const Icon(Icons.flash_on),
            tooltip: 'Toggle Flash',
            onPressed: () => _scannerController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            tooltip: 'Switch Camera',
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
                  color: Colors.black,
                ),
                clipBehavior: Clip.antiAlias,
                child: !_hasPermission
                    ? _buildPermissionDeniedView()
                    : _cameraErrorMessage != null
                        ? _buildErrorView(message: _cameraErrorMessage)
                        : Stack(
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
                            placeholderBuilder: (context, child) => _buildPlaceholderView(),
                            errorBuilder: (context, error, child) => _buildErrorView(error: error),
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

  Widget _buildPlaceholderView() {
    return Container(
      color: WalkieTheme.surfaceCard,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: WalkieTheme.primaryAmber,
              strokeWidth: 2.5,
            ),
            const SizedBox(height: 14),
            Text(
              _isCameraStarting ? 'Initializing camera...' : 'Connecting camera preview...',
              style: const TextStyle(
                color: WalkieTheme.textSecondary,
                fontSize: 13,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView({MobileScannerException? error, String? message}) {
    final displayMsg = message ?? error?.errorDetails?.message ?? error?.errorCode.name ?? 'Unknown error';
    return Container(
      color: WalkieTheme.surfaceCard,
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.videocam_off_rounded,
              color: WalkieTheme.alertCrimson,
              size: 40,
            ),
            const SizedBox(height: 10),
            const Text(
              'Camera failed to load',
              style: TextStyle(
                color: WalkieTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              displayMsg,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: WalkieTheme.textTertiary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: WalkieTheme.primaryAmber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              onPressed: _startCamera,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry Camera'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionDeniedView() {
    return Container(
      color: WalkieTheme.surfaceCard,
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              color: WalkieTheme.alertCrimson,
              size: 44,
            ),
            const SizedBox(height: 12),
            const Text(
              'Camera Access Required',
              style: TextStyle(
                color: WalkieTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please grant camera permission to scan channel QR codes.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: WalkieTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: _startCamera,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: WalkieTheme.primaryAmber),
                  ),
                  child: const Text('Request Again', style: TextStyle(color: WalkieTheme.primaryAmber)),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: openAppSettings,
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
