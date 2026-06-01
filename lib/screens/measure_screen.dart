import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/app_theme.dart';
import '../utils/measurement_storage.dart';
import '../models/measurement.dart';
import '../widgets/scan_overlay.dart';
import '../widgets/measurement_result_sheet.dart';
import '../widgets/crosshair_widget.dart';

class MeasureScreen extends StatefulWidget {
  const MeasureScreen({super.key});

  @override
  State<MeasureScreen> createState() => _MeasureScreenState();
}

class _MeasureScreenState extends State<MeasureScreen>
    with TickerProviderStateMixin {
  String _mode = 'ar';
  bool _cameraPermission = false;
  bool _isScanning = false;
  bool _surfaceDetected = false;
  bool _hasMeasurement = false;
  String _statusMsg = 'Initializing camera...';

  // Measurement state
  Offset? _pointA;
  Offset? _pointB;
  double _distanceCm = 0.0;
  String _unit = 'cm';
  int _tapCount = 0;

  // For reference mode
  double _referenceWidthCm = 8.56; // credit card default
  String _referenceObject = 'Credit Card';

  late AnimationController _scanLineController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _initCamera();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _mode = args['mode'] ?? 'ar';
      _updateStatusForMode();
    }
  }

  void _updateStatusForMode() {
    switch (_mode) {
      case 'ar':
        _statusMsg = 'Move phone slowly to detect surfaces';
        break;
      case 'reference':
        _statusMsg = 'Place reference object in the blue frame';
        break;
      case 'height':
        _statusMsg = 'Stand back and aim at the base of the object';
        break;
    }
    if (mounted) setState(() {});
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (mounted) {
      setState(() {
        _cameraPermission = status.isGranted;
        if (_cameraPermission) {
          _isScanning = true;
          _simulateSurfaceDetection();
        } else {
          _statusMsg = 'Camera permission required';
        }
      });
    }
  }

  // Simulates AR plane detection (replace with real ARCore/ARKit in production)
  void _simulateSurfaceDetection() {
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() {
          _surfaceDetected = true;
          _statusMsg = _mode == 'ar'
              ? 'Tap Point A to start measuring'
              : _mode == 'reference'
                  ? 'Reference detected! Tap object edges to measure'
                  : 'Tap the BASE of the object';
        });
      }
    });
  }

  void _onTapScreen(TapDownDetails details) {
    if (!_surfaceDetected) return;

    final pos = details.localPosition;

    setState(() {
      if (_tapCount == 0) {
        _pointA = pos;
        _pointB = null;
        _tapCount = 1;
        _distanceCm = 0;
        _hasMeasurement = false;
        _statusMsg = 'Point A set! Now tap Point B';
      } else if (_tapCount == 1) {
        _pointB = pos;
        _tapCount = 0;
        _hasMeasurement = true;
        _distanceCm = _calculateDistance(pos);
        _statusMsg = 'Measurement complete!';
        _showResultSheet();
      }
    });
  }

  double _calculateDistance(Offset pointB) {
    if (_pointA == null) return 0;

    // Simulated AR calculation:
    // In real AR: use ARCore/ARKit world coordinates from hit test
    // Here we simulate using pixel distance + estimated depth factor
    final dx = pointB.dx - _pointA!.dx;
    final dy = pointB.dy - _pointA!.dy;
    final pixelDist = sqrt(dx * dx + dy * dy);

    // Simulated conversion: assume ~1px = 0.12cm at 50cm distance
    // In real implementation: use actual 3D world coordinates
    final baseCm = pixelDist * 0.12;

    if (_mode == 'reference') {
      // Scale based on reference object width on screen
      // Assuming reference object is ~200px wide on screen
      final referencePixelWidth = 200.0;
      final scaleFactor = _referenceWidthCm / referencePixelWidth;
      return pixelDist * scaleFactor;
    }

    return baseCm + (Random().nextDouble() * 0.4 - 0.2); // ±0.2cm noise sim
  }

  void _showResultSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MeasurementResultSheet(
        distanceCm: _distanceCm,
        mode: _mode,
        unit: _unit,
        onUnitToggle: (u) => setState(() => _unit = u),
        onSave: (label) async {
          final m = Measurement(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            label: label,
            widthCm: _distanceCm,
            createdAt: DateTime.now(),
            unit: _unit,
          );
          await MeasurementStorage.save(m);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Saved: $label',
                    style:
                        GoogleFonts.spaceGrotesk(color: AppTheme.textPrimary)),
                backgroundColor: AppTheme.surface,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
        },
        onRetry: () {
          setState(() {
            _pointA = null;
            _pointB = null;
            _tapCount = 0;
            _hasMeasurement = false;
            _distanceCm = 0;
            _statusMsg = 'Tap Point A to start measuring';
          });
        },
      ),
    );
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Camera feed placeholder (replace with real Camera widget) ──
          _buildCameraBackground(),

          // ── AR Scan overlay ──
          if (_isScanning)
            ScanOverlay(
              scanLineController: _scanLineController,
              surfaceDetected: _surfaceDetected,
              mode: _mode,
            ),

          // ── Tap to measure area ──
          if (_surfaceDetected)
            GestureDetector(
              onTapDown: _onTapScreen,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),

          // ── Measurement points and line ──
          if (_pointA != null) _buildMeasurementOverlay(),

          // ── Top HUD ──
          _buildTopHUD(),

          // ── Status bar ──
          _buildStatusBar(),

          // ── Bottom controls ──
          _buildBottomControls(),

          // ── Permission denied ──
          if (!_cameraPermission && _statusMsg.contains('permission'))
            _buildPermissionDenied(),
        ],
      ),
    );
  }

  Widget _buildCameraBackground() {
    // In production: replace with Camera(controller: _cameraController) widget
    // This is the simulated camera background
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF060810),
      child: CustomPaint(
        painter: _SimCameraPainter(
          scanLineValue: _scanLineController,
          surfaceDetected: _surfaceDetected,
        ),
      ),
    );
  }

  Widget _buildTopHUD() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // Back
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.accent.withOpacity(0.3), width: 1),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: AppTheme.textPrimary, size: 18),
              ),
            ),

            const SizedBox(width: 12),

            // Mode label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.accent.withOpacity(0.3), width: 1),
              ),
              child: Row(
                children: [
                  Icon(
                    _mode == 'ar'
                        ? Icons.view_in_ar_rounded
                        : _mode == 'reference'
                            ? Icons.compare_arrows_rounded
                            : Icons.height_rounded,
                    color: AppTheme.accent,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _mode == 'ar'
                        ? 'AR MEASURE'
                        : _mode == 'reference'
                            ? 'REFERENCE'
                            : 'HEIGHT SENSOR',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Unit toggle
            GestureDetector(
              onTap: () =>
                  setState(() => _unit = _unit == 'cm' ? 'in' : 'cm'),
              child: Container(
                width: 56,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.accent.withOpacity(0.3), width: 1),
                ),
                child: Center(
                  child: Text(
                    _unit.toUpperCase(),
                    style: GoogleFonts.orbitron(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accent,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1);
  }

  Widget _buildStatusBar() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 72,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _surfaceDetected
                  ? AppTheme.accent.withOpacity(0.4)
                  : AppTheme.warning.withOpacity(0.4),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (_, __) => Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _surfaceDetected
                        ? Color.lerp(AppTheme.accent, AppTheme.accentDim,
                            _pulseController.value)!
                        : Color.lerp(AppTheme.warning,
                            AppTheme.warning.withOpacity(0.3),
                            _pulseController.value)!,
                    boxShadow: [
                      BoxShadow(
                        color: (_surfaceDetected
                                ? AppTheme.accent
                                : AppTheme.warning)
                            .withOpacity(0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _statusMsg,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMeasurementOverlay() {
    return CustomPaint(
      painter: _MeasurementPainter(
        pointA: _pointA!,
        pointB: _pointB,
        distanceCm: _distanceCm,
        unit: _unit,
      ),
      child: Stack(
        children: [
          // Point A crosshair
          Positioned(
            left: _pointA!.dx - 20,
            top: _pointA!.dy - 20,
            child: const CrosshairWidget(color: AppTheme.accent, label: 'A'),
          ),

          // Point B crosshair
          if (_pointB != null)
            Positioned(
              left: _pointB!.dx - 20,
              top: _pointB!.dy - 20,
              child: const CrosshairWidget(color: AppTheme.success, label: 'B'),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, MediaQuery.of(context).padding.bottom + 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.9),
            ],
          ),
        ),
        child: Column(
          children: [
            // Distance display (live)
            if (_hasMeasurement || (_pointA != null && _pointB == null))
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.accentGlow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _pointA != null && _pointB == null
                          ? 'Tap Point B...'
                          : '${_unit == 'cm' ? _distanceCm.toStringAsFixed(1) : (_distanceCm / 2.54).toStringAsFixed(2)} $_unit',
                      style: GoogleFonts.orbitron(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accent,
                      ),
                    ),
                  ],
                ),
              ).animate().scale(duration: 300.ms, curve: Curves.elasticOut),

            // Action row
            Row(
              children: [
                // Reset
                Expanded(
                  child: _ControlButton(
                    icon: Icons.refresh_rounded,
                    label: 'RESET',
                    color: AppTheme.textSecondary,
                    onTap: () {
                      setState(() {
                        _pointA = null;
                        _pointB = null;
                        _tapCount = 0;
                        _hasMeasurement = false;
                        _distanceCm = 0;
                        _statusMsg = 'Tap Point A to start measuring';
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // Main action
                Expanded(
                  flex: 2,
                  child: _ControlButton(
                    icon: _hasMeasurement
                        ? Icons.save_rounded
                        : Icons.touch_app_rounded,
                    label: _hasMeasurement ? 'SAVE RESULT' : 'TAP TO MEASURE',
                    color: AppTheme.accent,
                    isPrimary: true,
                    onTap: _hasMeasurement ? _showResultSheet : null,
                  ),
                ),

                const SizedBox(width: 12),

                // Flash
                Expanded(
                  child: _ControlButton(
                    icon: Icons.flash_on_rounded,
                    label: 'LIGHT',
                    color: AppTheme.textSecondary,
                    onTap: () {
                      // Toggle torch in production
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return Container(
      color: AppTheme.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_photography_rounded,
                color: AppTheme.error, size: 64),
            const SizedBox(height: 20),
            Text('Camera Access Required',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text('Please enable camera in settings',
                style: GoogleFonts.spaceGrotesk(color: AppTheme.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: openAppSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: AppTheme.background,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Open Settings',
                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Simulated Camera Background Painter ────────────────────────────────────

class _SimCameraPainter extends CustomPainter {
  final Animation<double> scanLineValue;
  final bool surfaceDetected;

  _SimCameraPainter(
      {required this.scanLineValue, required this.surfaceDetected})
      : super(repaint: scanLineValue);

  @override
  void paint(Canvas canvas, Size size) {
    // Simulated camera environment dots
    final dotPaint = Paint()
      ..color = AppTheme.accent.withOpacity(surfaceDetected ? 0.15 : 0.05)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.fill;

    final rng = Random(42);
    for (int i = 0; i < 80; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        rng.nextDouble() * 2 + 0.5,
        dotPaint,
      );
    }

    if (!surfaceDetected) {
      // Scan line
      final scanY = scanLineValue.value * size.height;
      final scanPaint = Paint()
        ..color = AppTheme.accent.withOpacity(0.4)
        ..strokeWidth = 2;

      canvas.drawLine(Offset(0, scanY), Offset(size.width, scanY), scanPaint);

      // Glow
      final glowPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            AppTheme.accent.withOpacity(0.15),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, scanY - 20, size.width, 40));

      canvas.drawRect(
          Rect.fromLTWH(0, scanY - 20, size.width, 40), glowPaint);
    }

    // Simulated plane mesh (when detected)
    if (surfaceDetected) {
      final meshPaint = Paint()
        ..color = AppTheme.accent.withOpacity(0.12)
        ..strokeWidth = 1;

      final gridStart = size.height * 0.45;
      final step = 40.0;

      for (double x = 0; x < size.width; x += step) {
        canvas.drawLine(
            Offset(x, gridStart), Offset(x, size.height), meshPaint);
      }
      for (double y = gridStart; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), meshPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ─── Measurement Line Painter ────────────────────────────────────────────────

class _MeasurementPainter extends CustomPainter {
  final Offset pointA;
  final Offset? pointB;
  final double distanceCm;
  final String unit;

  _MeasurementPainter({
    required this.pointA,
    this.pointB,
    required this.distanceCm,
    required this.unit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pointB == null) return;

    final linePaint = Paint()
      ..color = AppTheme.accent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    // Dashed line
    final dx = pointB!.dx - pointA.dx;
    final dy = pointB!.dy - pointA.dy;
    final dist = sqrt(dx * dx + dy * dy);
    final dashLen = 10.0;
    final gapLen = 6.0;
    double drawn = 0;

    while (drawn < dist) {
      final t0 = drawn / dist;
      final t1 = ((drawn + dashLen) / dist).clamp(0.0, 1.0);
      canvas.drawLine(
        Offset(pointA.dx + dx * t0, pointA.dy + dy * t0),
        Offset(pointA.dx + dx * t1, pointA.dy + dy * t1),
        linePaint,
      );
      drawn += dashLen + gapLen;
    }

    // Midpoint label
    if (distanceCm > 0) {
      final mid = Offset(
        (pointA.dx + pointB!.dx) / 2,
        (pointA.dy + pointB!.dy) / 2,
      );
      final label = unit == 'cm'
          ? '${distanceCm.toStringAsFixed(1)} cm'
          : '${(distanceCm / 2.54).toStringAsFixed(2)}"';

      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: AppTheme.accent,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            background: Paint()
              ..color = Colors.black.withOpacity(0.7)
              ..strokeWidth = 16
              ..style = PaintingStyle.stroke
              ..strokeJoin = StrokeJoin.round,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(
          canvas, Offset(mid.dx - tp.width / 2, mid.dy - tp.height / 2 - 20));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ─── Control Button ──────────────────────────────────────────────────────────

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isPrimary;
  final VoidCallback? onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    this.isPrimary = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isPrimary ? color : AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPrimary ? color : color.withOpacity(0.3),
          ),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  )
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isPrimary ? AppTheme.background : color,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isPrimary ? AppTheme.background : color,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
