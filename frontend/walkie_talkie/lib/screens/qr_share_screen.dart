import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/group.dart';
import '../theme.dart';

class QrShareScreen extends StatefulWidget {
  final Group group;

  const QrShareScreen({super.key, required this.group});

  @override
  State<QrShareScreen> createState() => _QrShareScreenState();
}

class _QrShareScreenState extends State<QrShareScreen> {
  bool _copied = false;

  void _copyPasscode() {
    HapticFeedback.mediumImpact();
    Clipboard.setData(ClipboardData(text: widget.group.joinToken));
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor: WalkieTheme.surfaceCardElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: WalkieTheme.readyEmerald),
        ),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: WalkieTheme.readyEmerald, size: 18),
            const SizedBox(width: 8),
            Text(
              'Passcode "${widget.group.joinToken}" copied to clipboard',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: WalkieTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  void _copyFullInvitation() {
    HapticFeedback.heavyImpact();
    final invitationText =
        'Join my secure Walkie Talkie radio squad!\n'
        'Channel: ${widget.group.name}\n'
        'Frequency Passcode: ${widget.group.joinToken}';
    Clipboard.setData(ClipboardData(text: invitationText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor: WalkieTheme.surfaceCardElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: WalkieTheme.primaryAmber),
        ),
        content: const Row(
          children: [
            Icon(Icons.share_rounded, color: WalkieTheme.primaryAmber, size: 18),
            SizedBox(width: 8),
            Text(
              'Squad invitation message copied to clipboard!',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: WalkieTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WalkieTheme.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: WalkieTheme.primaryAmber,
                    boxShadow: [
                      BoxShadow(
                        color: WalkieTheme.primaryAmber,
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'FREQ BEACON // QR SYNC',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
            const Text(
              'SECURE SQUAD DISPATCH TERMINAL',
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                color: WalkieTheme.textTertiary,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Copy Invitation',
            icon: const Icon(Icons.share_rounded, color: WalkieTheme.primaryAmber),
            onPressed: _copyFullInvitation,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Tactical Frequency Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: WalkieTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: WalkieTheme.surfaceCardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: WalkieTheme.primaryAmber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.graphic_eq_rounded,
                        size: 20,
                        color: WalkieTheme.primaryAmber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TARGET RADIO FREQUENCY',
                            style: TextStyle(
                              fontSize: 9,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: WalkieTheme.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.group.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: WalkieTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: WalkieTheme.readyEmerald.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: WalkieTheme.readyEmerald.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sensors_rounded, size: 12, color: WalkieTheme.readyEmerald),
                          SizedBox(width: 4),
                          Text(
                            'ACTIVE',
                            style: TextStyle(
                              fontSize: 10,
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
              ),

              const SizedBox(height: 20),

              // 2. Tactical Reticle QR Card Frame
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1114),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: WalkieTheme.primaryAmber.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: WalkieTheme.primaryAmber.withValues(alpha: 0.08),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Reticle HUD Header
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '[ TARGET RETICLE // SCAN ]',
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: WalkieTheme.primaryAmber,
                          ),
                        ),
                        Text(
                          'OPTICAL SYNC',
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            color: WalkieTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // QR with Tactical Corner Crosshairs
                    CustomPaint(
                      foregroundPainter: _TacticalReticlePainter(
                        color: WalkieTheme.primaryAmber,
                        cornerLength: 24,
                        strokeWidth: 3,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: QrImageView(
                          data: widget.group.joinToken,
                          version: QrVersions.auto,
                          size: 210.0,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Colors.black,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Aim Scanner Hint
                    const Text(
                      'AIM SQUAD SCANNER AT THIS CODE TO TUNE IN',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: WalkieTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 3. Digital Segmented Passcode Display Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: WalkieTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: WalkieTheme.surfaceCardBorder),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'MANUAL JOIN PASSCODE',
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: WalkieTheme.textTertiary,
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: _copyPasscode,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _copied
                                  ? WalkieTheme.readyEmerald.withValues(alpha: 0.2)
                                  : WalkieTheme.primaryAmber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _copied
                                  ? WalkieTheme.readyEmerald
                                  : WalkieTheme.primaryAmber.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _copied ? Icons.check_rounded : Icons.copy_rounded,
                                  size: 13,
                                  color: _copied ? WalkieTheme.readyEmerald : WalkieTheme.primaryAmber,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _copied ? 'COPIED' : 'COPY CODE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    color: _copied ? WalkieTheme.readyEmerald : WalkieTheme.primaryAmber,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Segmented Character Cells
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: widget.group.joinToken.split('').map((char) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: 38,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D0E10),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: WalkieTheme.primaryAmber.withValues(alpha: 0.45),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            char,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                              color: WalkieTheme.primaryAmber,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 4. Squad Sync Protocol Guide (Eliminates the empty lonely gap!)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: WalkieTheme.surfaceCardElevated,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: WalkieTheme.surfaceCardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.shield_outlined, size: 16, color: WalkieTheme.readyEmerald),
                        SizedBox(width: 8),
                        Text(
                          'SQUAD SYNC PROTOCOL',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: WalkieTheme.readyEmerald,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildProtocolStep(
                      step: '01',
                      title: 'POINT CAMERA AT RETICLE',
                      subtitle: 'Member uses "SCAN QR" on their squad terminal to join in 1 tap.',
                    ),
                    const SizedBox(height: 8),
                    _buildProtocolStep(
                      step: '02',
                      title: 'OR TRANSMIT 6-DIGIT CODE',
                      subtitle: 'Enter passcode manually on "PASSCODE" button if camera is unavailable.',
                    ),
                    const SizedBox(height: 8),
                    _buildProtocolStep(
                      step: '03',
                      title: 'INSTANT RADIO LINK',
                      subtitle: 'Voice stream synchronizes with 16k PCM low-latency full duplex audio.',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 5. Action Dock: Full-width Return Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text(
                    'DONE // RETURN TO CHANNEL',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProtocolStep({
    required String step,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: WalkieTheme.surfaceLowest,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: WalkieTheme.surfaceCardBorder),
          ),
          child: Text(
            step,
            style: const TextStyle(
              fontSize: 10,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: WalkieTheme.primaryAmber,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  color: WalkieTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10,
                  color: WalkieTheme.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Custom Canvas Painter that renders HUD corner reticle brackets around the QR container
class _TacticalReticlePainter extends CustomPainter {
  final Color color;
  final double cornerLength;
  final double strokeWidth;

  _TacticalReticlePainter({
    required this.color,
    required this.cornerLength,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    const double offset = 6.0;

    // Top-left
    canvas.drawLine(const Offset(-offset, -offset), Offset(cornerLength - offset, -offset), paint);
    canvas.drawLine(const Offset(-offset, -offset), Offset(-offset, cornerLength - offset), paint);

    // Top-right
    canvas.drawLine(Offset(size.width + offset, -offset), Offset(size.width - cornerLength + offset, -offset), paint);
    canvas.drawLine(Offset(size.width + offset, -offset), Offset(size.width + offset, cornerLength - offset), paint);

    // Bottom-left
    canvas.drawLine(Offset(-offset, size.height + offset), Offset(cornerLength - offset, size.height + offset), paint);
    canvas.drawLine(Offset(-offset, size.height + offset), Offset(-offset, size.height - cornerLength + offset), paint);

    // Bottom-right
    canvas.drawLine(Offset(size.width + offset, size.height + offset), Offset(size.width - cornerLength + offset, size.height + offset), paint);
    canvas.drawLine(Offset(size.width + offset, size.height + offset), Offset(size.width + offset, size.height - cornerLength + offset), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
