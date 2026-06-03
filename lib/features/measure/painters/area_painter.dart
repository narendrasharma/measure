import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ar/ar_math.dart';
import '../../../core/theme/app_theme.dart';

class AreaPainter extends CustomPainter {
  final List<Offset> points;
  final bool closed;
  final double perimCm, areaCm2;
  final String unit;

  const AreaPainter({
    required this.points, required this.closed,
    required this.perimCm, required this.areaCm2, required this.unit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // ── Fill ────────────────────────────────────────────────────────────────
    if (points.length >= 3) {
      final path = Path()..moveTo(points[0].dx, points[0].dy);
      for (int i = 1; i < points.length; i++) path.lineTo(points[i].dx, points[i].dy);
      if (closed) path.close();
      canvas.drawPath(path, Paint()..color = AppTheme.yellow.withAlpha(22)..style = PaintingStyle.fill);
      canvas.drawPath(path, Paint()
        ..color = AppTheme.yellow.withAlpha(closed ? 200 : 140)
        ..strokeWidth = 2.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    } else if (points.length == 2) {
      canvas.drawLine(points[0], points[1], Paint()
        ..color = AppTheme.yellow..strokeWidth = 2.5..strokeCap = StrokeCap.round);
    }

    // ── Segment labels ───────────────────────────────────────────────────────
    for (int i = 0; i < points.length - 1; i++) {
      final a = points[i], b = points[i + 1];
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      // Compute per-segment px distance as rough label
      final px = (b - a).distance;
      _smallLabel(canvas, '${px.toStringAsFixed(0)}px', mid);
    }

    // ── Centroid label ───────────────────────────────────────────────────────
    if (points.length >= 3 && perimCm > 0) {
      final cx = points.map((p) => p.dx).reduce((a, b) => a + b) / points.length;
      final cy = points.map((p) => p.dy).reduce((a, b) => a + b) / points.length;
      final lines = [
        fmtCm(perimCm, unit),
        if (areaCm2 > 0) '${areaCm2.toStringAsFixed(1)} cm²',
      ];
      _bigLabel(canvas, lines.join('\n'), Offset(cx, cy));
    }

    // ── Point markers ────────────────────────────────────────────────────────
    for (int i = 0; i < points.length; i++) {
      final isFirst = i == 0;
      final color = isFirst ? AppTheme.green : AppTheme.yellow;
      canvas.drawCircle(points[i], isFirst ? 10 : 7,
        Paint()..color = color.withAlpha(30));
      canvas.drawCircle(points[i], isFirst ? 8 : 5,
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.2);
      canvas.drawCircle(points[i], isFirst ? 3.5 : 2.5,
        Paint()..color = color);
      // Number badge
      final tp = TextPainter(
        text: TextSpan(text: '${i + 1}',
          style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr)..layout();
      final bg = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(points[i].dx, points[i].dy - 18),
          width: tp.width + 10, height: tp.height + 5),
        const Radius.circular(4));
      canvas.drawRRect(bg, Paint()..color = color);
      tp.paint(canvas, Offset(points[i].dx - tp.width / 2, points[i].dy - 18 - tp.height / 2));
    }

    // ── Close indicator ring around first point ───────────────────────────────
    if (!closed && points.length >= 3) {
      canvas.drawCircle(points.first, 24,
        Paint()..color = AppTheme.green.withAlpha(60)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }
  }

  void _smallLabel(Canvas canvas, String txt, Offset pos) {
    final tp = TextPainter(
      text: TextSpan(text: txt, style: const TextStyle(
        color: AppTheme.yellow, fontSize: 9, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr)..layout();
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(pos.dx, pos.dy - 12), width: tp.width + 8, height: tp.height + 5),
        const Radius.circular(4)),
      Paint()..color = Colors.black.withAlpha(180));
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - 12 - tp.height / 2));
  }

  void _bigLabel(Canvas canvas, String txt, Offset pos) {
    final tp = TextPainter(
      text: TextSpan(text: txt, style: const TextStyle(
        color: AppTheme.yellow, fontSize: 14, fontWeight: FontWeight.bold, height: 1.4)),
      textDirection: TextDirection.ltr, textAlign: TextAlign.center)..layout();
    final rr = RRect.fromRectAndRadius(
      Rect.fromCenter(center: pos, width: tp.width + 22, height: tp.height + 14),
      const Radius.circular(10));
    canvas.drawRRect(rr, Paint()..color = Colors.black.withAlpha(210));
    canvas.drawRRect(rr, Paint()..color = AppTheme.yellow.withAlpha(80)..style = PaintingStyle.stroke..strokeWidth = 1.2);
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant AreaPainter o) => true;
}
