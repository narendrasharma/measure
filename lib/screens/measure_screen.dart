import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:screenshot/screenshot.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vector_math/vector_math.dart' as vm;
import '../models/measurement.dart';
import '../utils/app_theme.dart';
import '../utils/measurement_storage.dart';
import '../widgets/crosshair_widget.dart';
import '../widgets/measurement_result_sheet.dart';
import '../widgets/scan_overlay.dart';

class MeasureScreen extends StatefulWidget {
  const MeasureScreen({super.key});
  @override
  State<MeasureScreen> createState() => _MeasureScreenState();
}

class _MeasureScreenState extends State<MeasureScreen>
    with TickerProviderStateMixin {
  // ── Mode ──────────────────────────────────────────────────────────────────
  String _mode = 'ar';

  // ── Camera ────────────────────────────────────────────────────────────────
  CameraController? _camCtrl;
  List<CameraDescription> _cameras = [];
  bool _cameraReady = false;
  bool _torchOn = false;

  // ── Screenshot ────────────────────────────────────────────────────────────
  final ScreenshotController _screenshotController = ScreenshotController();

  // ── Measurement state ─────────────────────────────────────────────────────
  Offset? _pointA;
  Offset? _pointB;
  // Multi-point perimeter
  final List<Offset> _perimeterPoints = [];
  bool _multiMode = false;

  double _distanceCm = 0.0;
  double _perimeterCm = 0.0;
  String _unit = 'cm';
  int _tapCount = 0;
  bool _hasMeasurement = false;
  String _statusMsg = 'Initializing camera...';
  bool _surfaceDetected = false;

  // ── Reference mode ────────────────────────────────────────────────────────
  // Standard credit card: 85.6mm × 54mm
  double _referenceWidthCm = 8.56;
  double? _referencePixelWidth; // set when user taps reference corners

  // ── Height sensor mode ────────────────────────────────────────────────────
  double _tiltAngleDeg = 0.0;
  double _distanceToObjectM = 1.0; // user sets this
  StreamSubscription? _accelSub;

  // ── Animation ─────────────────────────────────────────────────────────────
  late AnimationController _scanLineCtrl;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _scanLineCtrl = AnimationController(vsync: this, duration: 2.seconds)..repeat();
    _pulseCtrl    = AnimationController(vsync: this, duration: 1200.ms)..repeat(reverse: true);
    _initCamera();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _mode = args['mode'] ?? 'ar';
      _updateStatus();
    }
  }

  // ── Camera init ───────────────────────────────────────────────────────────
  Future<void> _initCamera() async {
    final camStatus = await Permission.camera.request();
    if (!camStatus.isGranted) {
      setState(() => _statusMsg = 'Camera permission required');
      return;
    }
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _statusMsg = 'No camera found');
        return;
      }
      _camCtrl = CameraController(
        _cameras[0],
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _camCtrl!.initialize();
      if (mounted) {
        setState(() {
          _cameraReady = true;
          _statusMsg = 'Camera ready — move phone to scan';
        });
        _simulateSurfaceDetect();
        if (_mode == 'height') _startAccelerometer();
      }
    } catch (e) {
      setState(() => _statusMsg = 'Camera error: $e');
    }
  }

  void _simulateSurfaceDetect() {
    // AR plane detection would come from ar_flutter_plugin hit results.
    // For reference & height modes we don't need it.
    Future.delayed((_mode == 'ar') ? 2.seconds : 800.ms, () {
      if (mounted) setState(() { _surfaceDetected = true; _updateStatus(); });
    });
  }

  void _updateStatus() {
    switch (_mode) {
      case 'ar':
        _statusMsg = _surfaceDetected ? 'Tap Point A on the object' : 'Move phone slowly to detect surface';
        break;
      case 'reference':
        _statusMsg = _referencePixelWidth == null
            ? 'Tap LEFT edge of credit card, then RIGHT edge'
            : 'Calibrated! Now tap object edges to measure';
        break;
      case 'height':
        _statusMsg = 'Aim at object base, enter distance, then top';
        break;
    }
    if (mounted) setState(() {});
  }

  // ── Torch toggle ──────────────────────────────────────────────────────────
  Future<void> _toggleTorch() async {
    if (_camCtrl == null || !_cameraReady) return;
    try {
      _torchOn = !_torchOn;
      await _camCtrl!.setFlashMode(_torchOn ? FlashMode.torch : FlashMode.off);
      setState(() {});
    } catch (_) {}
  }

  // ── Accelerometer (height mode) ───────────────────────────────────────────
  void _startAccelerometer() {
    _accelSub = accelerometerEventStream().listen((event) {
      // pitch angle: arctan(y / sqrt(x²+z²))
      final pitch = atan2(event.y, sqrt(event.x * event.x + event.z * event.z));
      if (mounted) setState(() => _tiltAngleDeg = pitch * 180 / pi);
    });
  }

  // ── Tap handler ───────────────────────────────────────────────────────────
  void _onTap(TapDownDetails d) {
    if (!_surfaceDetected && _mode == 'ar') return;
    final pos = d.localPosition;

    if (_multiMode) {
      // Perimeter mode: collect points
      setState(() {
        _perimeterPoints.add(pos);
        _perimeterCm = _calcPerimeter();
        _statusMsg = '${_perimeterPoints.length} points — tap more or press ✓';
      });
      return;
    }

    // Standard 2-point mode
    setState(() {
      if (_tapCount == 0) {
        _pointA = pos;
        _pointB = null;
        _tapCount = 1;
        _distanceCm = 0;
        _hasMeasurement = false;

        if (_mode == 'reference' && _referencePixelWidth == null) {
          _statusMsg = 'Now tap RIGHT edge of the card';
        } else {
          _statusMsg = 'Point A set — tap Point B';
        }
      } else {
        _pointB = pos;
        _tapCount = 0;
        _hasMeasurement = true;

        if (_mode == 'reference' && _referencePixelWidth == null) {
          // First two taps calibrate the reference
          _referencePixelWidth = _pixelDist(_pointA!, pos);
          _pointA = null;
          _pointB = null;
          _hasMeasurement = false;
          _statusMsg = 'Card calibrated! Tap object edges to measure';
          return;
        }

        _distanceCm = _calcDistance(pos);
        _statusMsg = 'Done! ${_distanceCm.toStringAsFixed(1)} cm';
        _showResult();
      }
    });
  }

  // ── Distance calculation ──────────────────────────────────────────────────
  double _pixelDist(Offset a, Offset b) {
    final dx = b.dx - a.dx, dy = b.dy - a.dy;
    return sqrt(dx * dx + dy * dy);
  }

  double _calcDistance(Offset b) {
    if (_pointA == null) return 0;
    final px = _pixelDist(_pointA!, b);

    if (_mode == 'reference') {
      // Scale by calibrated reference
      final refPx = _referencePixelWidth ?? 200.0;
      return px * (_referenceWidthCm / refPx);
    }

    if (_mode == 'height') {
      // Trigonometric height from tilt angle
      // h = distance * tan(angle)
      final angleRad = _tiltAngleDeg * pi / 180;
      return _distanceToObjectM * 100 * tan(angleRad.abs());
    }

    // AR mode: pixel-based with depth estimation
    // In full AR integration, use ar_flutter_plugin worldTransform difference.
    // Here: use focal-length heuristic (good approximation ~±10%)
    final screenH = MediaQuery.of(context).size.height;
    final focalLengthPx = screenH * 1.2; // approx focal length in px
    final depthM = 0.5; // assume 50cm default depth
    final realSizePer100px = (100 / focalLengthPx) * depthM * 100; // cm per 100px
    return px * (realSizePer100px / 100);
  }

  double _calcPerimeter() {
    if (_perimeterPoints.length < 2) return 0;
    double total = 0;
    for (int i = 0; i < _perimeterPoints.length - 1; i++) {
      total += _pixelDist(_perimeterPoints[i], _perimeterPoints[i + 1]);
    }
    // Close the shape
    if (_perimeterPoints.length > 2) {
      total += _pixelDist(_perimeterPoints.last, _perimeterPoints.first);
    }
    return total * (_referenceWidthCm / (_referencePixelWidth ?? 200.0));
  }

  // ── Screenshot + share ────────────────────────────────────────────────────
  Future<void> _captureAndShare() async {
    try {
      final bytes = await _screenshotController.capture(pixelRatio: 2.0);
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/dimscan_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Measured with DimScan: ${_distanceCm.toStringAsFixed(1)} cm');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  // ── Result bottom sheet ───────────────────────────────────────────────────
  void _showResult() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MeasurementResultSheet(
        distanceCm: _distanceCm,
        mode: _mode,
        unit: _unit,
        onUnitToggle: (u) => setState(() => _unit = u),
        onShare: _captureAndShare,
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
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Saved: $label', style: GoogleFonts.spaceGrotesk(color: AppTheme.textPrimary)),
              backgroundColor: AppTheme.surface,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ));
          }
        },
        onRetry: _reset,
      ),
    );
  }

  void _reset() {
    setState(() {
      _pointA = null; _pointB = null;
      _tapCount = 0; _hasMeasurement = false;
      _distanceCm = 0; _perimeterPoints.clear(); _perimeterCm = 0;
      _updateStatus();
    });
  }

  @override
  void dispose() {
    _scanLineCtrl.dispose();
    _pulseCtrl.dispose();
    _accelSub?.cancel();
    _camCtrl?.dispose();
    super.dispose();
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Screenshot(
        controller: _screenshotController,
        child: Stack(children: [
          // ── Real camera feed ──
          _buildCamera(),

          // ── AR scan overlay ──
          ScanOverlay(
            scanLineController: _scanLineCtrl,
            surfaceDetected: _surfaceDetected,
            mode: _mode,
          ),

          // ── Tap detector ──
          GestureDetector(
            onTapDown: _onTap,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),

          // ── Measurement drawing ──
          if (_pointA != null || _perimeterPoints.isNotEmpty)
            _buildMeasurementOverlay(),

          // ── Height mode tilt display ──
          if (_mode == 'height' && _surfaceDetected) _buildTiltIndicator(),

          // ── Top HUD ──
          _buildTopHUD(),

          // ── Status pill ──
          _buildStatusPill(),

          // ── Bottom controls ──
          _buildBottomControls(),

          // ── Reference distance input (height mode) ──
          if (_mode == 'height' && _surfaceDetected) _buildDistanceInput(),

          // ── No camera permission ──
          if (_statusMsg.contains('permission')) _buildPermissionDenied(),
        ]),
      ),
    );
  }

  // ── Camera widget ──────────────────────────────────────────────────────────
  Widget _buildCamera() {
    if (!_cameraReady || _camCtrl == null) {
      return Container(
        color: const Color(0xFF060810),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2),
            const SizedBox(height: 16),
            Text('Starting camera...', style: GoogleFonts.spaceGrotesk(color: AppTheme.textSecondary)),
          ]),
        ),
      );
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _camCtrl!.value.previewSize!.height,
          height: _camCtrl!.value.previewSize!.width,
          child: CameraPreview(_camCtrl!),
        ),
      ),
    );
  }

  // ── Measurement overlay (canvas) ──────────────────────────────────────────
  Widget _buildMeasurementOverlay() {
    return Stack(children: [
      // Canvas for lines
      CustomPaint(
        size: MediaQuery.of(context).size,
        painter: _MeasurePainter(
          pointA: _pointA,
          pointB: _pointB,
          perimeterPoints: _perimeterPoints,
          distanceCm: _distanceCm,
          perimeterCm: _perimeterCm,
          unit: _unit,
        ),
      ),
      // Crosshair A
      if (_pointA != null)
        Positioned(
          left: _pointA!.dx - 20, top: _pointA!.dy - 20,
          child: const CrosshairWidget(color: AppTheme.accent, label: 'A'),
        ),
      // Crosshair B
      if (_pointB != null)
        Positioned(
          left: _pointB!.dx - 20, top: _pointB!.dy - 20,
          child: const CrosshairWidget(color: AppTheme.success, label: 'B'),
        ),
      // Perimeter dots
      ..._perimeterPoints.asMap().entries.map((e) => Positioned(
        left: e.value.dx - 8, top: e.value.dy - 8,
        child: Container(
          width: 16, height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.accent,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [BoxShadow(color: AppTheme.accent.withOpacity(0.5), blurRadius: 8)],
          ),
          child: Center(child: Text('${e.key + 1}',
            style: const TextStyle(color: Colors.black, fontSize: 7, fontWeight: FontWeight.bold))),
        ),
      )),
    ]);
  }

  // ── Tilt indicator for height mode ────────────────────────────────────────
  Widget _buildTiltIndicator() {
    return Positioned(
      left: 20, top: MediaQuery.of(context).size.height * 0.35,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
        ),
        child: Column(children: [
          Text('TILT', style: GoogleFonts.spaceGrotesk(fontSize: 9, color: AppTheme.textDim, letterSpacing: 2)),
          Text('${_tiltAngleDeg.abs().toStringAsFixed(1)}°',
            style: GoogleFonts.orbitron(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.accent)),
          const SizedBox(height: 4),
          _TiltBar(angle: _tiltAngleDeg),
        ]),
      ),
    );
  }

  // ── Distance input for height mode ────────────────────────────────────────
  Widget _buildDistanceInput() {
    return Positioned(
      right: 20, top: MediaQuery.of(context).size.height * 0.35,
      child: Container(
        width: 110,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.warning.withOpacity(0.4)),
        ),
        child: Column(children: [
          Text('DIST TO OBJ', style: GoogleFonts.spaceGrotesk(fontSize: 8, color: AppTheme.textDim, letterSpacing: 1)),
          const SizedBox(height: 6),
          Text('${_distanceToObjectM.toStringAsFixed(1)} m',
            style: GoogleFonts.orbitron(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.warning)),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _SmallBtn('-', () => setState(() => _distanceToObjectM = max(0.1, _distanceToObjectM - 0.1))),
            _SmallBtn('+', () => setState(() => _distanceToObjectM += 0.1)),
          ]),
        ]),
      ),
    );
  }

  // ── Top HUD ───────────────────────────────────────────────────────────────
  Widget _buildTopHUD() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          // Back
          _HudBtn(icon: Icons.arrow_back_ios_new_rounded, onTap: () => Navigator.pop(context)),
          const SizedBox(width: 10),
          // Mode badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
            ),
            child: Row(children: [
              Icon(_modeIcon(), color: AppTheme.accent, size: 15),
              const SizedBox(width: 6),
              Text(_modeLabel(), style: GoogleFonts.spaceGrotesk(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary, letterSpacing: 1.5)),
            ]),
          ),
          const Spacer(),
          // Multi-point toggle
          _HudBtn(
            icon: _multiMode ? Icons.polyline_rounded : Icons.straighten_rounded,
            color: _multiMode ? AppTheme.accent : AppTheme.textSecondary,
            onTap: () => setState(() { _multiMode = !_multiMode; _reset(); }),
          ),
          const SizedBox(width: 8),
          // Torch
          _HudBtn(
            icon: _torchOn ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
            color: _torchOn ? AppTheme.warning : AppTheme.textSecondary,
            onTap: _toggleTorch,
          ),
          const SizedBox(width: 8),
          // Unit toggle
          GestureDetector(
            onTap: () => setState(() => _unit = _unit == 'cm' ? 'in' : 'cm'),
            child: Container(
              width: 50, height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
              ),
              child: Center(child: Text(_unit.toUpperCase(),
                style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.accent))),
            ),
          ),
        ]),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1);
  }

  // ── Status pill ───────────────────────────────────────────────────────────
  Widget _buildStatusPill() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 64,
      left: 0, right: 0,
      child: Center(
        child: AnimatedContainer(
          duration: 300.ms,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.72),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _surfaceDetected ? AppTheme.accent.withOpacity(0.4) : AppTheme.warning.withOpacity(0.4)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _surfaceDetected
                    ? Color.lerp(AppTheme.accent, AppTheme.accentDim, _pulseCtrl.value)!
                    : Color.lerp(AppTheme.warning, AppTheme.warning.withOpacity(0.3), _pulseCtrl.value)!,
                  boxShadow: [BoxShadow(
                    color: (_surfaceDetected ? AppTheme.accent : AppTheme.warning).withOpacity(0.5),
                    blurRadius: 6)],
                ),
              ),
            ),
            const SizedBox(width: 9),
            Text(_statusMsg, style: GoogleFonts.spaceGrotesk(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }

  // ── Bottom controls ───────────────────────────────────────────────────────
  Widget _buildBottomControls() {
    final displayVal = _unit == 'cm'
        ? _distanceCm.toStringAsFixed(1)
        : (_distanceCm / 2.54).toStringAsFixed(2);

    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(context).padding.bottom + 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withOpacity(0.92)]),
        ),
        child: Column(children: [
          // Live readout
          if (_hasMeasurement || (_pointA != null && !_hasMeasurement))
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.accentGlow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(
                  _hasMeasurement ? '$displayVal $_unit' : 'Tap Point B...',
                  style: GoogleFonts.orbitron(fontSize: 30, fontWeight: FontWeight.w700, color: AppTheme.accent),
                ),
              ]),
            ).animate().scale(duration: 300.ms, curve: Curves.elasticOut),

          // Perimeter readout
          if (_multiMode && _perimeterPoints.length >= 2)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.success.withOpacity(0.4)),
              ),
              child: Text(
                'Perimeter: ${_perimeterCm.toStringAsFixed(1)} cm  •  ${_perimeterPoints.length} pts',
                style: GoogleFonts.orbitron(fontSize: 13, color: AppTheme.success),
              ),
            ),

          // Buttons row
          Row(children: [
            Expanded(child: _CtrlBtn(icon: Icons.refresh_rounded, label: 'RESET',
              color: AppTheme.textSecondary, onTap: _reset)),
            const SizedBox(width: 10),

            // Multi-point confirm
            if (_multiMode && _perimeterPoints.length >= 3)
              Expanded(child: _CtrlBtn(
                icon: Icons.check_circle_rounded, label: 'CONFIRM',
                color: AppTheme.success, isPrimary: true,
                onTap: () {
                  setState(() {
                    _distanceCm = _perimeterCm;
                    _hasMeasurement = true;
                  });
                  _showResult();
                },
              ))
            else
              Expanded(flex: 2, child: _CtrlBtn(
                icon: _hasMeasurement ? Icons.save_rounded : Icons.touch_app_rounded,
                label: _hasMeasurement ? 'SAVE / SHARE' : (_multiMode ? 'TAP CORNERS' : 'TAP TO MEASURE'),
                color: AppTheme.accent, isPrimary: true,
                onTap: _hasMeasurement ? _showResult : null,
              )),

            const SizedBox(width: 10),
            Expanded(child: _CtrlBtn(
              icon: Icons.share_rounded, label: 'SHARE',
              color: AppTheme.textSecondary,
              onTap: _hasMeasurement ? _captureAndShare : null,
            )),
          ]),
        ]),
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return Container(
      color: AppTheme.background,
      child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.no_photography_rounded, color: AppTheme.error, size: 64),
        const SizedBox(height: 20),
        Text('Camera Access Required', style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        Text('Please enable camera permission in settings', style: GoogleFonts.spaceGrotesk(color: AppTheme.textSecondary)),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: openAppSettings,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: AppTheme.background,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: Text('Open Settings', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600)),
        ),
      ])),
    );
  }

  IconData _modeIcon() => _mode == 'ar' ? Icons.view_in_ar_rounded
      : _mode == 'reference' ? Icons.compare_arrows_rounded : Icons.height_rounded;
  String _modeLabel() => _mode == 'ar' ? 'AR MEASURE' : _mode == 'reference' ? 'REFERENCE' : 'HEIGHT';
}

// ── Measurement Painter ──────────────────────────────────────────────────────
class _MeasurePainter extends CustomPainter {
  final Offset? pointA, pointB;
  final List<Offset> perimeterPoints;
  final double distanceCm, perimeterCm;
  final String unit;

  _MeasurePainter({
    this.pointA, this.pointB,
    required this.perimeterPoints,
    required this.distanceCm, required this.perimeterCm,
    required this.unit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AppTheme.accent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    // Perimeter polygon
    if (perimeterPoints.length >= 2) {
      final path = Path()..moveTo(perimeterPoints[0].dx, perimeterPoints[0].dy);
      for (int i = 1; i < perimeterPoints.length; i++) {
        path.lineTo(perimeterPoints[i].dx, perimeterPoints[i].dy);
      }
      if (perimeterPoints.length > 2) path.close();
      canvas.drawPath(path, linePaint..color = AppTheme.success);
      // Fill
      canvas.drawPath(path, Paint()..color = AppTheme.success.withOpacity(0.08)..style = PaintingStyle.fill);
      return;
    }

    // 2-point dashed line
    if (pointA == null || pointB == null) return;
    _drawDashed(canvas, pointA!, pointB!, linePaint);

    // Label
    if (distanceCm > 0) {
      final label = unit == 'cm'
          ? '${distanceCm.toStringAsFixed(1)} cm'
          : '${(distanceCm / 2.54).toStringAsFixed(2)}"';
      final mid = Offset((pointA!.dx + pointB!.dx) / 2, (pointA!.dy + pointB!.dy) / 2);
      _drawLabel(canvas, label, mid);
    }
  }

  void _drawDashed(Canvas canvas, Offset a, Offset b, Paint p) {
    final dx = b.dx - a.dx, dy = b.dy - a.dy;
    final dist = sqrt(dx * dx + dy * dy);
    double drawn = 0;
    while (drawn < dist) {
      final t0 = drawn / dist;
      final t1 = min((drawn + 10) / dist, 1.0);
      canvas.drawLine(
        Offset(a.dx + dx * t0, a.dy + dy * t0),
        Offset(a.dx + dx * t1, a.dy + dy * t1), p);
      drawn += 16;
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset pos) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(
        color: AppTheme.accent, fontSize: 14, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    // Background
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(pos.dx, pos.dy - 22), width: tp.width + 16, height: tp.height + 8),
      const Radius.circular(6));
    canvas.drawRRect(rect, Paint()..color = Colors.black.withOpacity(0.75));
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - 22 - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => true;
}

// ── Small helper widgets ─────────────────────────────────────────────────────
class _HudBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  const _HudBtn({required this.icon, required this.onTap, this.color = AppTheme.textPrimary});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 42, height: 42,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppTheme.accent.withOpacity(0.25)),
      ),
      child: Icon(icon, color: color, size: 19),
    ),
  );
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isPrimary;
  final VoidCallback? onTap;
  const _CtrlBtn({required this.icon, required this.label, required this.color, this.isPrimary = false, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedOpacity(
      duration: 200.ms,
      opacity: onTap == null ? 0.4 : 1.0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: isPrimary ? color : AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isPrimary ? color : color.withOpacity(0.3)),
          boxShadow: isPrimary ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12)] : [],
        ),
        child: Column(children: [
          Icon(icon, color: isPrimary ? AppTheme.background : color, size: 20),
          const SizedBox(height: 3),
          Text(label, style: GoogleFonts.spaceGrotesk(
            fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.8,
            color: isPrimary ? AppTheme.background : color)),
        ]),
      ),
    ),
  );
}

class _SmallBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SmallBtn(this.label, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32, height: 28,
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.warning.withOpacity(0.4)),
      ),
      child: Center(child: Text(label,
        style: GoogleFonts.spaceGrotesk(fontSize: 16, color: AppTheme.warning, fontWeight: FontWeight.bold))),
    ),
  );
}

class _TiltBar extends StatelessWidget {
  final double angle;
  const _TiltBar({required this.angle});
  @override
  Widget build(BuildContext context) {
    final norm = (angle.clamp(-45.0, 45.0) + 45) / 90;
    return SizedBox(
      width: 60, height: 8,
      child: Stack(children: [
        Container(decoration: BoxDecoration(color: AppTheme.surfaceElevated, borderRadius: BorderRadius.circular(4))),
        FractionallySizedBox(
          widthFactor: norm,
          child: Container(decoration: BoxDecoration(
            color: AppTheme.accent, borderRadius: BorderRadius.circular(4),
            boxShadow: [BoxShadow(color: AppTheme.accent.withOpacity(0.5), blurRadius: 6)],
          )),
        ),
      ]),
    );
  }
}
