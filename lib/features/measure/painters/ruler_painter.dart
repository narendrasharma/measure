import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ar/ar_math.dart';
import '../../../core/theme/app_theme.dart';

class RulerPainter extends CustomPainter {
  final Offset? ptA, ptB, liveDot;
  final double distanceCm;
  final String unit;
  final bool locked;
  final double pulse;

  const RulerPainter({
    this.ptA, this.ptB, this.liveDot,
    required this.distanceCm,
    required this.unit, required this.locked, required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Always draw the crosshair/dot where finger is (before A is placed)
    if (liveDot != null && ptA == null) {
      _drawDot(canvas, liveDot!, AppTheme.yellow, pulse);
      return;
    }
    if (ptA == null) return;

    final end = ptB?.dx != null ? ptB! : liveDot;
    if (end == null) {
      _drawEndPoint(canvas, ptA!, 'A', AppTheme.yellow, pulse);
      return;
    }

    final a = ptA!, b = end;
    final dx = b.dx - a.dx, dy = b.dy - a.dy;
    final len = sqrt(dx * dx + dy * dy);
    if (len < 2) return;

    final ux = dx / len, uy = dy / len;   // unit direction
    final nx = -uy, ny = ux;              // unit perpendicular

    final lineColor = locked ? AppTheme.green : AppTheme.yellow;

    // ── Glow ─────────────────────────────────────────────────────────────
    canvas.drawLine(a, b, Paint()
      ..color = lineColor.withAlpha(30)
      ..strokeWidth = 22..strokeCap = StrokeCap.round);

    // ── Main measurement line ─────────────────────────────────────────────
    canvas.drawLine(a, b, Paint()
      ..color = lineColor
      ..strokeWidth = 3.0..strokeCap = StrokeCap.round);

    // ── End caps (perpendicular ticks) ────────────────────────────────────
    const capLen = 14.0;
    final capPaint = Paint()..color = lineColor..strokeWidth = 2.5..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(a.dx - nx * capLen, a.dy - ny * capLen),
                    Offset(a.dx + nx * capLen, a.dy + ny * capLen), capPaint);
    canvas.drawLine(Offset(b.dx - nx * capLen, b.dy - ny * capLen),
                    Offset(b.dx + nx * capLen, b.dy + ny * capLen), capPaint);

    // ── Ruler tick marks ──────────────────────────────────────────────────
    if (distanceCm > 0) {
      final pxPerCm = len / distanceCm;
      final tickCm = _tickInterval(distanceCm);
      final tickPx = tickCm * pxPerCm;
      if (tickPx >= 6) {
        int n = 1;
        double d = tickPx;
        while (d < len - 2) {
          final px = a.dx + ux * d, py = a.dy + uy * d;
          final major = n % 5 == 0;
          final tl = major ? 11.0 : 5.0;
          canvas.drawLine(
            Offset(px - nx * tl, py - ny * tl),
            Offset(px + nx * tl, py + ny * tl),
            Paint()..color = lineColor.withAlpha(major ? 200 : 100)..strokeWidth = major ? 1.8 : 1.0);
          if (major && tickPx > 28) {
            _smallLabel(canvas, '${(n * tickCm).toStringAsFixed(tickCm < 1 ? 1 : 0)}',
              Offset(px, py), lineColor);
          }
          d += tickPx; n++;
        }
      }
    }

    // ── Distance label ────────────────────────────────────────────────────
    final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    _distLabel(canvas, fmtCm(distanceCm, unit), mid, lineColor, large: locked);

    // ── Point markers ─────────────────────────────────────────────────────
    _drawEndPoint(canvas, a, 'A', lineColor, pulse);
    _drawEndPoint(canvas, b, locked ? 'B' : '', lineColor, pulse);
  }

  double _tickInterval(double cm) {
    if (cm < 2)   return 0.1;
    if (cm < 5)   return 0.5;
    if (cm < 20)  return 1.0;
    if (cm < 50)  return 2.0;
    if (cm < 200) return 10.0;
    return 50.0;
  }

  void _drawEndPoint(Canvas canvas, Offset pt, String label, Color color, double pulse) {
    // Outer glow ring
    canvas.drawCircle(pt, 18 + pulse * 4, Paint()..color = color.withAlpha(18));
    // Ring
    canvas.drawCircle(pt, 10, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.5);
    // Dot
    canvas.drawCircle(pt, 4, Paint()..color = color);
    // Label badge
    if (label.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(text: label, style: TextStyle(
          color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr)..layout();
      final rr = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(pt.dx, pt.dy - 22), width: tp.width + 12, height: tp.height + 6),
        const Radius.circular(5));
      canvas.drawRRect(rr, Paint()..color = color);
      tp.paint(canvas, Offset(pt.dx - tp.width / 2, pt.dy - 22 - tp.height / 2));
    }
  }

  void _drawDot(Canvas canvas, Offset pt, Color color, double pulse) {
    canvas.drawCircle(pt, 20 + pulse * 6, Paint()..color = color.withAlpha(18));
    canvas.drawCircle(pt, 10, Paint()..color = color.withAlpha(160)..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawCircle(pt, 4,  Paint()..color = color);
    // Crosshair lines
    final cp = Paint()..color = color.withAlpha(120)..strokeWidth = 1.2;
    canvas.drawLine(Offset(pt.dx - 24, pt.dy), Offset(pt.dx - 12, pt.dy), cp);
    canvas.drawLine(Offset(pt.dx + 12, pt.dy), Offset(pt.dx + 24, pt.dy), cp);
    canvas.drawLine(Offset(pt.dx, pt.dy - 24), Offset(pt.dx, pt.dy - 12), cp);
    canvas.drawLine(Offset(pt.dx, pt.dy + 12), Offset(pt.dx, pt.dy + 24), cp);
  }

  void _distLabel(Canvas canvas, String txt, Offset pos, Color color, {bool large = false}) {
    final sz = large ? 17.0 : 14.0;
    final tp = TextPainter(
      text: TextSpan(text: txt, style: TextStyle(
        color: color, fontSize: sz, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr)..layout();
    final rr = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(pos.dx, pos.dy - (large ? 32 : 26)),
        width: tp.width + 22, height: tp.height + 12),
      const Radius.circular(9));
    canvas.drawRRect(rr, Paint()..color = Colors.black.withAlpha(220));
    canvas.drawRRect(rr, Paint()..color = color.withAlpha(80)..style = PaintingStyle.stroke..strokeWidth = 1.2);
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - (large ? 32 : 26) - tp.height / 2));
  }

  void _smallLabel(Canvas canvas, String txt, Offset pos, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: txt, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr)..layout();
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(pos.dx, pos.dy - 15), width: tp.width + 8, height: tp.height + 5),
        const Radius.circular(4)),
      Paint()..color = Colors.black.withAlpha(180));
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - 15 - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant RulerPainter o) => true;
}
