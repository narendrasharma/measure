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
import '../../core/ar/ar_math.dart';
import '../../core/models/measurement.dart';
import '../../core/theme/app_theme.dart';
import 'painters/ruler_painter.dart';
import 'painters/area_painter.dart';
import 'painters/level_painter.dart';
import 'widgets/result_sheet.dart';
import 'widgets/mode_switcher.dart';

// ─── Mode ─────────────────────────────────────────────────────────────────────
enum MeasureMode { ruler, area, level, height }

// ─── Screen ───────────────────────────────────────────────────────────────────
class MeasureScreen extends StatefulWidget {
  const MeasureScreen({super.key});
  @override State<MeasureScreen> createState() => _MeasureScreenState();
}

class _MeasureScreenState extends State<MeasureScreen>
    with TickerProviderStateMixin {

  // ── Camera ──────────────────────────────────────────────────────────────
  CameraController? _cam;
  bool _camReady = false;
  bool _torch    = false;

  // ── AR ───────────────────────────────────────────────────────────────────
  ARCamera? _ar;
  bool _surfaceDetected = false;

  // ── Mode ─────────────────────────────────────────────────────────────────
  MeasureMode _mode = MeasureMode.ruler;
  String _unit = 'cm';

  // ── Ruler mode ────────────────────────────────────────────────────────────
  // User drags to create a ruler line — just like iPhone Measure
  ARHitPoint? _ptA;           // locked start point
  ARHitPoint? _ptB;           // locked end point
  Offset?     _liveDot;       // crosshair follows the finger / gyro
  double      _rulerCm = 0;
  bool        _hasResult = false;

  // ── Area mode ─────────────────────────────────────────────────────────────
  // Tap corners → auto-close polygon
  final List<ARHitPoint> _areaPts = [];
  bool  _areaClosed = false;
  double _areaCm2   = 0;
  double _perimCm   = 0;

  // ── Level mode ────────────────────────────────────────────────────────────
  double _pitch = 0, _roll = 0;
  bool   _isLevel = false;

  // ── Height mode ───────────────────────────────────────────────────────────
  double _distM    = 1.5;    // user-set distance to object in metres
  double _heightCm = 0;

  // ── Sensors ──────────────────────────────────────────────────────────────
  StreamSubscription? _accelSub;

  // ── Screenshot ───────────────────────────────────────────────────────────
  final ScreenshotController _shot = ScreenshotController();

  // ── Animations ───────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late AnimationController _dotCtrl;
  late AnimationController _scanCtrl;

  // ── Crosshair world pos (for live distance while moving) ──────────────────
  Vec3? _liveWorld;

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: 900.ms)..repeat(reverse: true);
    _dotCtrl   = AnimationController(vsync: this, duration: 500.ms)..repeat(reverse: true);
    _scanCtrl  = AnimationController(vsync: this, duration: 2200.ms)..repeat();
    _initCamera();
    _initSensors();
  }

  // ── Camera ────────────────────────────────────────────────────────────────
  Future<void> _initCamera() async {
    if (!await Permission.camera.request().isGranted) return;
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) return;
      _cam = CameraController(cams.first, ResolutionPreset.high,
          enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
      await _cam!.initialize();
      if (!mounted) return;
      setState(() => _camReady = true);
      // Init AR after we know the screen size
      WidgetsBinding.instance.addPostFrameCallback((_) => _initAR());
      // Simulate surface detection after 1.5 s
      Future.delayed(1500.ms, () {
        if (mounted) setState(() => _surfaceDetected = true);
      });
    } catch (_) {}
  }

  void _initAR() {
    if (!mounted) return;
    final sz = MediaQuery.of(context).size;
    _ar = ARCamera(
      screen: sz,
      fl: ARCamera.estimateFL(sz.height),
      heightCm: 50,
      pitchRad: 0.40,
    );
  }

  // ── Sensors ───────────────────────────────────────────────────────────────
  void _initSensors() {
    _accelSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.uiInterval).listen((e) {
      if (!mounted) return;
      final p = atan2(e.y, sqrt(e.x * e.x + e.z * e.z)) * 180 / pi;
      final r = atan2(e.x, e.z) * 180 / pi;
      setState(() {
        _pitch = p; _roll = r;
        _isLevel = p.abs() < 2.0 && r.abs() < 2.0;
        // Update AR pitch so depth estimation tracks real tilt
        _ar?.pitchRad = p.abs() * pi / 180;
        _ar?.rollRad  = r * pi / 180;
        // Recompute height in height mode
        if (_mode == MeasureMode.height) {
          _heightCm = _distM * 100 * tan(p.abs() * pi / 180);
        }
      });
    });
  }

  // ── Gesture — Pan (ruler drag) ────────────────────────────────────────────
  void _onPanStart(DragStartDetails d) {
    if (_mode != MeasureMode.ruler) return;
    _reset(soft: true);
    final hit = _ar?.hitGround(d.localPosition);
    setState(() {
      _ptA = ARHitPoint(hit ?? Vec3.zero, d.localPosition);
      _liveDot = d.localPosition;
      _liveWorld = hit;
      _hasResult = false;
    });
    HapticFeedback.selectionClick();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_mode != MeasureMode.ruler || _ptA == null) return;
    final hit = _ar?.hitGround(d.localPosition);
    final dist = hit != null ? _ptA!.world.distanceTo(hit) : _pixelCm(_ptA!.screen, d.localPosition);
    setState(() {
      _liveDot   = d.localPosition;
      _liveWorld = hit;
      _rulerCm   = dist;
    });
  }

  void _onPanEnd(DragEndDetails d) {
    if (_mode != MeasureMode.ruler || _ptA == null || _liveDot == null) return;
    final hit = _ar?.hitGround(_liveDot!) ?? Vec3.zero;
    setState(() {
      _ptB        = ARHitPoint(hit, _liveDot!);
      _hasResult  = true;
      _rulerCm    = _ptA!.world.distanceTo(hit);
    });
    HapticFeedback.mediumImpact();
    if (_rulerCm > 0.3) _showResult(_rulerCm, 'Ruler');
  }

  // ── Gesture — Tap (AR / area) ─────────────────────────────────────────────
  void _onTap(TapDownDetails d) {
    if (!_surfaceDetected) return;
    switch (_mode) {
      case MeasureMode.ruler:
        // Tap resets
        if (_hasResult) _reset();
        break;
      case MeasureMode.area:
        _tapArea(d.localPosition);
        break;
      case MeasureMode.level:
        break;
      case MeasureMode.height:
        break;
    }
  }

  void _tapArea(Offset pos) {
    if (_areaClosed) { _reset(); return; }
    final hit = _ar?.hitGround(pos) ?? Vec3(pos.dx / 10, 0, pos.dy / 10);
    setState(() {
      _areaPts.add(ARHitPoint(hit, pos));
      _recalcArea();
    });
    HapticFeedback.selectionClick();

    // Auto-close if ≥ 3 pts and user taps near the first point
    if (_areaPts.length >= 3) {
      final firstPx = _areaPts.first.screen;
      final d = (pos - firstPx).distance;
      if (d < 30) {
        setState(() { _areaClosed = true; });
        HapticFeedback.mediumImpact();
        _showResult(_perimCm, 'Area', areaCm2: _areaCm2);
      }
    }
  }

  void _recalcArea() {
    if (_areaPts.length < 2) { _perimCm = _areaCm2 = 0; return; }
    double perim = 0;
    for (int i = 0; i < _areaPts.length - 1; i++) {
      perim += _areaPts[i].world.distanceTo(_areaPts[i + 1].world);
    }
    if (_areaClosed) perim += _areaPts.last.world.distanceTo(_areaPts.first.world);
    _perimCm = perim;
    _areaCm2 = polygonArea(_areaPts.map((p) => p.world).toList());
  }

  // ── Live dot follows finger in ruler mode ─────────────────────────────────
  void _onPointerMove(PointerMoveEvent e) {
    if (_mode == MeasureMode.ruler && _ptA == null) {
      setState(() => _liveDot = e.localPosition);
    }
  }

  // ── Reset ─────────────────────────────────────────────────────────────────
  void _reset({bool soft = false}) {
    setState(() {
      _ptA = _ptB = null;
      _liveDot = _liveWorld = null;
      _rulerCm = 0;
      _hasResult = false;
      if (!soft) {
        _areaPts.clear();
        _areaClosed = false;
        _areaCm2 = _perimCm = 0;
      }
    });
  }

  void _undoArea() {
    if (_areaPts.isEmpty) return;
    setState(() {
      _areaPts.removeLast();
      _areaClosed = false;
      _recalcArea();
    });
    HapticFeedback.selectionClick();
  }

  // ── Pixel fallback distance (when AR plane is unavailable) ────────────────
  double _pixelCm(Offset a, Offset b) {
    final px = (b - a).distance;
    return (px / (_ar?.fl ?? 1200)) * (_ar?.heightCm ?? 50);
  }

  // ── Unit cycling ──────────────────────────────────────────────────────────
  void _cycleUnit() {
    const u = ['cm', 'mm', 'm', 'in', 'ft'];
    setState(() => _unit = u[(u.indexOf(_unit) + 1) % u.length]);
  }

  // ── Torch ─────────────────────────────────────────────────────────────────
  Future<void> _toggleTorch() async {
    if (!_camReady) return;
    _torch = !_torch;
    await _cam!.setFlashMode(_torch ? FlashMode.torch : FlashMode.off);
    setState(() {});
  }

  // ── Show result sheet ─────────────────────────────────────────────────────
  void _showResult(double cm, String source, {double? areaCm2}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ResultSheet(
        cm: cm, unit: _unit, source: source, areaCm2: areaCm2,
        onUnitChange: (u) => setState(() => _unit = u),
        onShare: _shareScreenshot,
        onSave: (label) async {
          await MeasurementStore.save(Measurement(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            label: label, primaryCm: cm,
            areaCm2: areaCm2, mode: _mode.name,
            unit: _unit, createdAt: DateTime.now(),
          ));
        },
        onRetry: () { Navigator.pop(context); _reset(); },
      ),
    );
  }

  Future<void> _shareScreenshot() async {
    try {
      final bytes = await _shot.capture(pixelRatio: 2.5);
      if (bytes == null) return;
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/measure_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Measured with DimScan');
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _pulseCtrl.dispose(); _dotCtrl.dispose(); _scanCtrl.dispose();
    _accelSub?.cancel();
    _cam?.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Screenshot(
        controller: _shot,
        child: Listener(
          onPointerMove: _onPointerMove,
          child: GestureDetector(
            onPanStart:  _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd:    _onPanEnd,
            onTapDown:   _onTap,
            behavior: HitTestBehavior.opaque,
            child: Stack(children: [
              // 1. Camera feed
              _CameraFeed(cam: _cam, ready: _camReady),

              // 2. AR grid (ruler + area modes)
              if (_surfaceDetected && _mode != MeasureMode.level)
                _ARGrid(ctrl: _scanCtrl),

              // 3. Measurement drawing
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => CustomPaint(
                  size: MediaQuery.of(context).size,
                  painter: switch (_mode) {
                    MeasureMode.ruler => RulerPainter(
                      ptA: _ptA?.screen, ptB: _ptB?.screen,
                      liveDot: _liveDot,
                      distanceCm: _rulerCm, unit: _unit,
                      locked: _hasResult, pulse: _pulseCtrl.value),
                    MeasureMode.area => AreaPainter(
                      points: _areaPts.map((p) => p.screen).toList(),
                      closed: _areaClosed,
                      perimCm: _perimCm, areaCm2: _areaCm2, unit: _unit),
                    MeasureMode.level => LevelPainter(
                      pitch: _pitch, roll: _roll,
                      isLevel: _isLevel, pulse: _pulseCtrl.value),
                    MeasureMode.height => _HeightPainter(
                      pitch: _pitch, heightCm: _heightCm, distM: _distM, unit: _unit),
                  },
                ),
              ),

              // 4. Top HUD
              _TopHUD(
                mode: _mode,
                torch: _torch,
                unit: _unit,
                onBack: () => Navigator.pop(context),
                onTorch: _toggleTorch,
                onUnit: _cycleUnit,
                onHistory: () => Navigator.pushNamed(context, '/history'),
              ),

              // 5. Mode switcher (bottom tabs — iPhone style)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: ModeSwitcher(
                  current: _mode,
                  unit: _unit,
                  rulerCm: _rulerCm,
                  perimCm: _perimCm,
                  areaCm2: _areaCm2,
                  heightCm: _heightCm,
                  pitch: _pitch,
                  distM: _distM,
                  areaPtCount: _areaPts.length,
                  areaClosed: _areaClosed,
                  hasResult: _hasResult,
                  isLevel: _isLevel,
                  surfaceReady: _surfaceDetected,
                  onModeChange: (m) { setState(() => _mode = m); _reset(); },
                  onReset: _reset,
                  onUndo: _mode == MeasureMode.area ? _undoArea : null,
                  onDistChange: (v) => setState(() {
                    _distM = v;
                    _heightCm = _distM * 100 * tan(_pitch.abs() * pi / 180);
                  }),
                  onSaveResult: () {
                    if (_mode == MeasureMode.ruler && _hasResult) {
                      _showResult(_rulerCm, 'Ruler');
                    } else if (_mode == MeasureMode.area && _areaPts.length >= 2) {
                      _areaClosed = true;
                      _recalcArea();
                      _showResult(_perimCm, 'Area', areaCm2: _areaCm2);
                    } else if (_mode == MeasureMode.height) {
                      _showResult(_heightCm, 'Height');
                    }
                  },
                  onAddPoint: () {
                    if (_mode == MeasureMode.area) {
                      final center = MediaQuery.of(context).size.center(Offset.zero);
                      _tapArea(center);
                    }
                  },
                ),
              ),

              // 6. Surface not detected overlay
              if (!_surfaceDetected && _camReady)
                _ScanningOverlay(ctrl: _scanCtrl),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── Camera Feed ──────────────────────────────────────────────────────────────
class _CameraFeed extends StatelessWidget {
  final CameraController? cam;
  final bool ready;
  const _CameraFeed({required this.cam, required this.ready});

  @override
  Widget build(BuildContext context) {
    if (!ready || cam == null) {
      return Container(
        color: const Color(0xFF0A0A0A),
        child: const Center(child: CircularProgressIndicator(
            color: AppTheme.yellow, strokeWidth: 2)),
      );
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width:  cam!.value.previewSize!.height,
          height: cam!.value.previewSize!.width,
          child: CameraPreview(cam!),
        ),
      ),
    );
  }
}

// ─── AR Grid ─────────────────────────────────────────────────────────────────
class _ARGrid extends StatelessWidget {
  final AnimationController ctrl;
  const _ARGrid({required this.ctrl});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) => CustomPaint(
        size: MediaQuery.of(context).size,
        painter: _ARGridPainter(ctrl.value),
      ),
    ),
  );
}

class _ARGridPainter extends CustomPainter {
  final double t;
  _ARGridPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final horizon = size.height * 0.38;
    final gridPaint = Paint()..color = AppTheme.yellow.withAlpha(14)..strokeWidth = 0.7;
    final vp = Offset(size.width / 2, horizon);

    // Horizontal perspective lines
    for (int i = 1; i <= 10; i++) {
      final y = horizon + (size.height - horizon) * (i / 10.0);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    // Vertical converging lines
    for (int i = 0; i <= 12; i++) {
      final x = size.width * i / 12.0;
      canvas.drawLine(vp, Offset(x, size.height), gridPaint);
    }

    // Scan line
    final scanY = horizon + (size.height - horizon) * t;
    canvas.drawLine(Offset(0, scanY), Offset(size.width, scanY),
      Paint()..color = AppTheme.yellow.withAlpha(55)..strokeWidth = 1.5);

    // Corner brackets
    _drawBrackets(canvas, size);
  }

  void _drawBrackets(Canvas canvas, Size size) {
    const p = 28.0, a = 22.0;
    final paint = Paint()
      ..color = AppTheme.yellow.withAlpha(90)
      ..strokeWidth = 2.0..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    for (final c in [
      [Offset(p, p), Offset(p + a, p), Offset(p, p + a)],
      [Offset(size.width - p, p), Offset(size.width - p - a, p), Offset(size.width - p, p + a)],
      [Offset(p, size.height - p), Offset(p + a, size.height - p), Offset(p, size.height - p - a)],
      [Offset(size.width - p, size.height - p), Offset(size.width - p - a, size.height - p), Offset(size.width - p, size.height - p - a)],
    ]) {
      canvas.drawLine(c[0], c[1], paint);
      canvas.drawLine(c[0], c[2], paint);
    }
  }

  @override bool shouldRepaint(_ARGridPainter o) => o.t != t;
}

// ─── Scanning Overlay ─────────────────────────────────────────────────────────
class _ScanningOverlay extends StatelessWidget {
  final AnimationController ctrl;
  const _ScanningOverlay({required this.ctrl});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      color: Colors.black.withAlpha(80),
      child: Center(child: AnimatedBuilder(
        animation: ctrl,
        builder: (_, __) => Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 60, height: 60,
            child: CircularProgressIndicator(
              value: ctrl.value,
              color: AppTheme.yellow,
              backgroundColor: AppTheme.yellow.withAlpha(30),
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(height: 16),
          Text('Move your phone slowly to\ndetect the surface…',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: Colors.white,
              shadows: [const Shadow(blurRadius: 8, color: Colors.black)])),
        ]),
      )),
    ),
  );
}

// ─── Top HUD ──────────────────────────────────────────────────────────────────
class _TopHUD extends StatelessWidget {
  final MeasureMode mode;
  final bool torch;
  final String unit;
  final VoidCallback onBack, onTorch, onUnit, onHistory;
  const _TopHUD({required this.mode, required this.torch, required this.unit,
    required this.onBack, required this.onTorch, required this.onUnit, required this.onHistory});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(children: [
          _Btn(Icons.arrow_back_ios_new_rounded, onBack),
          const Spacer(),
          // Mode label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(150),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.yellow.withAlpha(80)),
            ),
            child: Text(mode.name.toUpperCase(),
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700,
                color: AppTheme.yellow, letterSpacing: 1.5)),
          ),
          const Spacer(),
          _Btn(torch ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded, onTorch,
            color: torch ? AppTheme.yellow : AppTheme.grey),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onUnit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(150),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.yellow.withAlpha(70)),
              ),
              child: Text(unit.toUpperCase(),
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800,
                  color: AppTheme.yellow)),
            ),
          ),
          const SizedBox(width: 8),
          _Btn(Icons.history_rounded, onHistory, color: AppTheme.grey),
        ]),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.08);
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  const _Btn(this.icon, this.onTap, {this.color = AppTheme.white});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(140),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(25)),
      ),
      child: Icon(icon, color: color, size: 18),
    ),
  );
}

// ─── Height mode painter (inline — simple) ────────────────────────────────────
class _HeightPainter extends CustomPainter {
  final double pitch, heightCm, distM;
  final String unit;
  _HeightPainter({required this.pitch, required this.heightCm, required this.distM, required this.unit});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height * 0.45;

    // Draw triangle: camera → top of object → bottom of object
    final base = Offset(cx, cy + 80);
    final top  = Offset(cx + 120, cy - 80);
    final bot  = Offset(cx + 120, cy + 80);

    final p = Paint()..color = AppTheme.yellow.withAlpha(180)..strokeWidth = 2.5..strokeCap = StrokeCap.round;
    canvas.drawLine(base, top, p);
    canvas.drawLine(base, bot, p);
    canvas.drawLine(bot, top, p..color = AppTheme.yellow.withAlpha(80));

    // Height label
    _label(canvas, fmtCm(heightCm, unit), Offset(cx + 145, cy),
      AppTheme.yellow, 18);

    // Angle arc
    final arc = Paint()..color = AppTheme.green.withAlpha(120)..strokeWidth = 2..style = PaintingStyle.stroke;
    canvas.drawArc(Rect.fromCenter(center: base, width: 80, height: 80),
      -pi / 2, -pitch.abs() * pi / 180, false, arc);
    _label(canvas, '${pitch.abs().toStringAsFixed(1)}°', base + const Offset(0, -50), AppTheme.green, 13);

    // Dist label
    _label(canvas, '${distM.toStringAsFixed(1)} m', Offset(cx + 60, cy + 100), AppTheme.grey, 12);
  }

  void _label(Canvas canvas, String txt, Offset pos, Color color, double size) {
    final tp = TextPainter(
      text: TextSpan(text: txt, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr)..layout();
    final bg = RRect.fromRectAndRadius(
      Rect.fromCenter(center: pos, width: tp.width + 14, height: tp.height + 8),
      const Radius.circular(6));
    canvas.drawRRect(bg, Paint()..color = Colors.black.withAlpha(180));
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _HeightPainter o) =>
    o.pitch != pitch || o.heightCm != heightCm;
}
