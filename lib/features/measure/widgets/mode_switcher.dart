import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/ar/ar_math.dart';
import '../../../core/theme/app_theme.dart';
import '../measure_screen.dart';

/// Bottom control panel — iPhone Measure app style.
/// Shows big readout, mode tabs, and contextual action buttons.
class ModeSwitcher extends StatelessWidget {
  final MeasureMode current;
  final String unit;
  final double rulerCm, perimCm, areaCm2, heightCm, pitch, distM;
  final int areaPtCount;
  final bool areaClosed, hasResult, isLevel, surfaceReady;
  final ValueChanged<MeasureMode> onModeChange;
  final VoidCallback onReset, onSaveResult, onAddPoint;
  final VoidCallback? onUndo;
  final ValueChanged<double> onDistChange;

  const ModeSwitcher({
    super.key,
    required this.current, required this.unit,
    required this.rulerCm, required this.perimCm, required this.areaCm2,
    required this.heightCm, required this.pitch, required this.distM,
    required this.areaPtCount, required this.areaClosed,
    required this.hasResult, required this.isLevel, required this.surfaceReady,
    required this.onModeChange, required this.onReset, required this.onSaveResult,
    required this.onAddPoint, this.onUndo, required this.onDistChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withAlpha(245)]),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // ── Big value readout ───────────────────────────────────────────
            _buildReadout(),
            const SizedBox(height: 14),

            // ── Height mode: distance slider ────────────────────────────────
            if (current == MeasureMode.height) ...[
              _buildDistSlider(context),
              const SizedBox(height: 12),
            ],

            // ── Area mode: close-polygon hint ───────────────────────────────
            if (current == MeasureMode.area && areaPtCount >= 3 && !areaClosed)
              _hint('Tap near Point 1 to close the shape', AppTheme.green),

            // ── Action buttons ──────────────────────────────────────────────
            _buildActions(context),
            const SizedBox(height: 12),

            // ── Mode tabs ───────────────────────────────────────────────────
            _buildModeTabs(),
          ]),
        ),
      ),
    );
  }

  // ── Big readout ────────────────────────────────────────────────────────────
  Widget _buildReadout() {
    String val = '';
    String sub = '';
    Color color = AppTheme.yellow;

    switch (current) {
      case MeasureMode.ruler:
        val = rulerCm > 0 ? fmtCm(rulerCm, unit) : (surfaceReady ? 'Drag to measure' : '');
        color = hasResult ? AppTheme.green : AppTheme.yellow;
        break;
      case MeasureMode.area:
        if (areaPtCount == 0) { val = 'Tap corners'; }
        else if (perimCm > 0) {
          val = fmtCm(perimCm, unit);
          sub = areaCm2 > 0 ? '${areaCm2.toStringAsFixed(1)} cm²' : '';
          color = areaClosed ? AppTheme.green : AppTheme.yellow;
        } else {
          val = '$areaPtCount ${areaPtCount == 1 ? "point" : "points"}';
        }
        break;
      case MeasureMode.level:
        val = isLevel ? '0.0°' : '${pitch.abs().toStringAsFixed(1)}°';
        color = isLevel ? AppTheme.green : Colors.white;
        sub = isLevel ? 'LEVEL' : '';
        break;
      case MeasureMode.height:
        val = heightCm > 0 ? fmtCm(heightCm, unit) : '—';
        sub = 'HEIGHT';
        break;
    }

    return AnimatedSwitcher(
      duration: 200.ms,
      child: Column(key: ValueKey(val), mainAxisSize: MainAxisSize.min, children: [
        Text(val, style: GoogleFonts.inter(
          fontSize: val.length > 10 ? 32 : 44,
          fontWeight: FontWeight.w200,
          color: color,
          letterSpacing: -1,
        )),
        if (sub.isNotEmpty)
          Text(sub, style: GoogleFonts.inter(fontSize: 14, color: color.withAlpha(160), letterSpacing: 1)),
      ]),
    );
  }

  // ── Distance slider (height mode) ─────────────────────────────────────────
  Widget _buildDistSlider(BuildContext context) {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Distance to object', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.grey)),
        Text('${distM.toStringAsFixed(1)} m', style: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.yellow)),
      ]),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor: AppTheme.yellow,
          inactiveTrackColor: AppTheme.greyDark,
          thumbColor: AppTheme.yellow,
          overlayColor: AppTheme.yellow.withAlpha(30),
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          trackHeight: 3,
        ),
        child: Slider(
          value: distM.clamp(0.3, 20.0),
          min: 0.3, max: 20.0, divisions: 197,
          onChanged: onDistChange,
        ),
      ),
    ]);
  }

  // ── Action buttons ─────────────────────────────────────────────────────────
  Widget _buildActions(BuildContext context) {
    final canSave = hasResult ||
      (current == MeasureMode.area && areaPtCount >= 2) ||
      (current == MeasureMode.height && heightCm > 0) ||
      (current == MeasureMode.level);

    return Row(children: [
      // Undo (area) or Reset
      _ActionBtn(
        icon: onUndo != null ? Icons.undo_rounded : Icons.refresh_rounded,
        label: onUndo != null ? 'UNDO' : 'RESET',
        onTap: onUndo ?? onReset,
      ),
      const SizedBox(width: 10),

      // Main CTA — big yellow button
      Expanded(
        flex: 2,
        child: _ActionBtn(
          icon: _ctaIcon(),
          label: _ctaLabel(),
          isPrimary: canSave,
          onTap: canSave ? onSaveResult : (current == MeasureMode.area ? onAddPoint : null),
        ),
      ),

      const SizedBox(width: 10),

      // History
      _ActionBtn(
        icon: Icons.collections_bookmark_rounded,
        label: 'SAVED',
        onTap: () => Navigator.pushNamed(context, '/history'),
      ),
    ]);
  }

  IconData _ctaIcon() => switch (current) {
    MeasureMode.ruler  => hasResult ? Icons.save_rounded : Icons.swipe_rounded,
    MeasureMode.area   => areaClosed ? Icons.save_rounded : Icons.touch_app_rounded,
    MeasureMode.level  => Icons.share_rounded,
    MeasureMode.height => Icons.save_rounded,
  };

  String _ctaLabel() => switch (current) {
    MeasureMode.ruler  => hasResult ? 'SAVE' : 'DRAG',
    MeasureMode.area   => areaClosed ? 'SAVE' : (areaPtCount == 0 ? 'TAP' : 'ADD POINT'),
    MeasureMode.level  => 'CAPTURE',
    MeasureMode.height => heightCm > 0 ? 'SAVE' : 'TILT',
  };

  // ── Mode tabs ──────────────────────────────────────────────────────────────
  Widget _buildModeTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: MeasureMode.values.map((m) {
          final sel = m == current;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onModeChange(m);
              },
              child: AnimatedContainer(
                duration: 200.ms,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: sel ? AppTheme.yellow : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_modeIcon(m), size: 18,
                    color: sel ? Colors.black : AppTheme.grey),
                  const SizedBox(height: 3),
                  Text(_modeLabel(m), style: GoogleFonts.inter(
                    fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5,
                    color: sel ? Colors.black : AppTheme.grey)),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _hint(String text, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: GoogleFonts.inter(
      fontSize: 11, color: color, fontWeight: FontWeight.w500)),
  );

  IconData _modeIcon(MeasureMode m) => switch (m) {
    MeasureMode.ruler  => Icons.straighten_rounded,
    MeasureMode.area   => Icons.crop_free_rounded,
    MeasureMode.level  => Icons.water_rounded,
    MeasureMode.height => Icons.height_rounded,
  };

  String _modeLabel(MeasureMode m) => switch (m) {
    MeasureMode.ruler  => 'RULER',
    MeasureMode.area   => 'AREA',
    MeasureMode.level  => 'LEVEL',
    MeasureMode.height => 'HEIGHT',
  };
}

// ── Action button ──────────────────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isPrimary;

  const _ActionBtn({required this.icon, required this.label,
    this.onTap, this.isPrimary = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: 150.ms,
        opacity: onTap == null ? 0.28 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: isPrimary ? AppTheme.yellow : AppTheme.surfaceHigh,
            borderRadius: BorderRadius.circular(13),
            boxShadow: isPrimary
              ? [BoxShadow(color: AppTheme.yellow.withAlpha(70), blurRadius: 12)]
              : [],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 22,
              color: isPrimary ? Colors.black : AppTheme.grey),
            const SizedBox(height: 3),
            Text(label, style: GoogleFonts.inter(
              fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.6,
              color: isPrimary ? Colors.black : AppTheme.grey)),
          ]),
        ),
      ),
    );
  }
}
