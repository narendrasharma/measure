import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Spirit level painter — identical UX to iPhone Measure level mode.
class LevelPainter extends CustomPainter {
  final double pitch, roll;
  final bool isLevel;
  final double pulse;

  const LevelPainter({
    required this.pitch, required this.roll,
    required this.isLevel, required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;

    // ── Background fill ─────────────────────────────────────────────────────
    // iPhone splits screen green when level — half black/half green
    if (isLevel) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = AppTheme.green.withAlpha(20));
    }

    // ── Horizon line ─────────────────────────────────────────────────────────
    // Rotates with roll, shifts with pitch
    final rollRad = roll * pi / 180;
    final pitchOff = pitch * 3.5;
    final lineColor = isLevel ? AppTheme.green : Colors.white;
    final linePaint = Paint()
      ..color = lineColor.withAlpha(220)
      ..strokeWidth = 3.0..strokeCap = StrokeCap.round;

    final halfW = size.width * 0.55;
    final dx = halfW * cos(rollRad), dy = halfW * sin(rollRad);
    canvas.drawLine(
      Offset(cx - dx, cy + dy + pitchOff),
      Offset(cx + dx, cy - dy + pitchOff),
      linePaint);

    // Center circle
    canvas.drawCircle(Offset(cx, cy + pitchOff), 28,
      Paint()..color = lineColor.withAlpha(30));
    canvas.drawCircle(Offset(cx, cy + pitchOff), 20,
      Paint()..color = lineColor.withAlpha(isLevel ? 200 : 100)
              ..style = PaintingStyle.stroke..strokeWidth = 2.5);

    // ── Reference line (center — always horizontal) ───────────────────────
    canvas.drawLine(
      Offset(cx - halfW, cy),
      Offset(cx + halfW, cy),
      Paint()..color = Colors.white.withAlpha(40)..strokeWidth = 1);
    canvas.drawCircle(Offset(cx, cy), 6,
      Paint()..color = Colors.white.withAlpha(60));

    // ── Angle readout ────────────────────────────────────────────────────────
    final label = isLevel ? '0.0°' : '${pitch.toStringAsFixed(1)}°';
    final tp = TextPainter(
      text: TextSpan(text: label, style: TextStyle(
        color: lineColor,
        fontSize: isLevel ? 52 : 46,
        fontWeight: FontWeight.w300,
        fontFamily: 'monospace',
      )),
      textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy + (isLevel ? 50 : 55)));

    // Sub-label
    final sub = isLevel ? 'LEVEL' : (roll.abs() > 2 ? 'Roll ${roll.toStringAsFixed(1)}°' : '');
    if (sub.isNotEmpty) {
      final sp = TextPainter(
        text: TextSpan(text: sub, style: TextStyle(
          color: lineColor.withAlpha(160), fontSize: 13, fontWeight: FontWeight.w500)),
        textDirection: TextDirection.ltr)..layout();
      sp.paint(canvas, Offset(cx - sp.width / 2, cy + 110));
    }

    // ── Corner angle indicators ───────────────────────────────────────────────
    _cornerDeg(canvas, size, pitch, roll);
  }

  void _cornerDeg(Canvas canvas, Size size, double p, double r) {
    final items = [
      ['PITCH', '${p.toStringAsFixed(1)}°', Offset(18, size.height - 60)],
      ['ROLL',  '${r.toStringAsFixed(1)}°', Offset(size.width - 80, size.height - 60)],
    ];
    for (final item in items) {
      final lbl = item[0] as String;
      final val = item[1] as String;
      final pos = item[2] as Offset;
      final tp1 = TextPainter(
        text: TextSpan(text: lbl, style: const TextStyle(
          color: AppTheme.grey, fontSize: 9, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr)..layout();
      tp1.paint(canvas, pos);
      final tp2 = TextPainter(
        text: TextSpan(text: val, style: const TextStyle(
          color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
        textDirection: TextDirection.ltr)..layout();
      tp2.paint(canvas, pos + Offset(0, 14));
    }
  }

  @override
  bool shouldRepaint(covariant LevelPainter o) =>
    o.pitch != pitch || o.roll != roll || o.pulse != pulse;
}
