import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class ScanOverlay extends StatelessWidget {
  final AnimationController scanLineController;
  final bool surfaceDetected;
  final String mode;

  const ScanOverlay({
    super.key,
    required this.scanLineController,
    required this.surfaceDetected,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          // Corner brackets
          _buildCornerBrackets(context),

          // Center reticle
          if (!surfaceDetected)
            Center(
              child: AnimatedBuilder(
                animation: scanLineController,
                builder: (_, __) => Opacity(
                  opacity: 0.3 + scanLineController.value * 0.7,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.accent, width: 1.5),
                    ),
                    child: const Center(
                      child: Icon(Icons.my_location_rounded,
                          color: AppTheme.accent, size: 22),
                    ),
                  ),
                ),
              ),
            ),

          // Surface detected grid indicator
          if (surfaceDetected && mode == 'ar')
            Positioned(
              bottom: 180,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppTheme.success.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: AppTheme.success, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Surface Detected',
                        style: TextStyle(
                          color: AppTheme.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCornerBrackets(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width * 0.65;
    final h = size.height * 0.35;
    final left = (size.width - w) / 2;
    final top = (size.height - h) / 2 - 40;
    const bracketSize = 24.0;
    const strokeWidth = 2.5;
    final color =
        surfaceDetected ? AppTheme.success : AppTheme.accent;

    return AnimatedBuilder(
      animation: scanLineController,
      builder: (_, __) {
        final opacity = surfaceDetected
            ? 1.0
            : 0.5 + scanLineController.value * 0.5;
        return Stack(
          children: [
            // Top-left
            Positioned(
              left: left,
              top: top,
              child: Opacity(
                opacity: opacity,
                child: _Corner(color: color, rotate: 0),
              ),
            ),
            // Top-right
            Positioned(
              left: left + w - bracketSize,
              top: top,
              child: Opacity(
                opacity: opacity,
                child: _Corner(color: color, rotate: 1),
              ),
            ),
            // Bottom-left
            Positioned(
              left: left,
              top: top + h - bracketSize,
              child: Opacity(
                opacity: opacity,
                child: _Corner(color: color, rotate: 3),
              ),
            ),
            // Bottom-right
            Positioned(
              left: left + w - bracketSize,
              top: top + h - bracketSize,
              child: Opacity(
                opacity: opacity,
                child: _Corner(color: color, rotate: 2),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Corner extends StatelessWidget {
  final Color color;
  final int rotate; // 0=TL, 1=TR, 2=BR, 3=BL

  const _Corner({required this.color, required this.rotate});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotate * 1.5708, // 90 degrees each
      child: CustomPaint(
        size: const Size(24, 24),
        painter: _CornerPainter(color: color),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  _CornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(const Offset(0, 0), Offset(size.width, 0), paint);
    canvas.drawLine(const Offset(0, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
