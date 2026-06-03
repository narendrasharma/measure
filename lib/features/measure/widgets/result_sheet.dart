import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/ar/ar_math.dart';
import '../../../core/theme/app_theme.dart';

class ResultSheet extends StatefulWidget {
  final double cm;
  final double? areaCm2;
  final String unit, source;
  final ValueChanged<String> onUnitChange;
  final ValueChanged<String> onSave;
  final VoidCallback onShare, onRetry;

  const ResultSheet({
    super.key,
    required this.cm, this.areaCm2,
    required this.unit, required this.source,
    required this.onUnitChange, required this.onSave,
    required this.onShare, required this.onRetry,
  });

  @override
  State<ResultSheet> createState() => _ResultSheetState();
}

class _ResultSheetState extends State<ResultSheet> {
  late String _unit;
  final _label = TextEditingController(text: 'Measurement');

  @override
  void initState() { super.initState(); _unit = widget.unit; }
  @override
  void dispose() { _label.dispose(); super.dispose(); }

  double get _val => switch (_unit) {
    'mm' => widget.cm * 10,
    'm'  => widget.cm / 100,
    'in' => widget.cm / 2.54,
    'ft' => widget.cm / 30.48,
    _    => widget.cm,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 8, 20,
        MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: AppTheme.greyDark, borderRadius: BorderRadius.circular(2))),

        // Source chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.yellow.withAlpha(22),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.yellow.withAlpha(80)),
          ),
          child: Text('${widget.source.toUpperCase()} MEASUREMENT',
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700,
              color: AppTheme.yellow, letterSpacing: 1.8)),
        ),
        const SizedBox(height: 20),

        // ── Big value ─────────────────────────────────────────────────────────
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: '${_val.toStringAsFixed(2)} $_unit'));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Copied to clipboard', style: GoogleFonts.inter(color: Colors.white)),
              backgroundColor: AppTheme.surfaceHigh,
              behavior: SnackBarBehavior.floating,
              duration: 1500.ms,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.yellow.withAlpha(80)),
              boxShadow: [BoxShadow(color: AppTheme.yellow.withAlpha(40), blurRadius: 24, spreadRadius: 2)],
            ),
            child: Column(children: [
              Text('${_val.toStringAsFixed(_unit == 'mm' ? 0 : _unit == 'cm' ? 1 : 2)} $_unit',
                style: GoogleFonts.inter(fontSize: 54, fontWeight: FontWeight.w200,
                  color: AppTheme.yellow, letterSpacing: -2, height: 1)),
              if (widget.areaCm2 != null) ...[
                const SizedBox(height: 6),
                Text('${widget.areaCm2!.toStringAsFixed(1)} cm²',
                  style: GoogleFonts.inter(fontSize: 18, color: AppTheme.yellow.withAlpha(160),
                    fontWeight: FontWeight.w300)),
              ],
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.copy_rounded, size: 12, color: AppTheme.grey),
                const SizedBox(width: 4),
                Text('Tap to copy', style: GoogleFonts.inter(fontSize: 10, color: AppTheme.grey)),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        // ── Unit chips ────────────────────────────────────────────────────────
        Row(mainAxisAlignment: MainAxisAlignment.center,
          children: ['cm', 'mm', 'm', 'in', 'ft'].map((u) =>
            GestureDetector(
              onTap: () { setState(() => _unit = u); widget.onUnitChange(u); },
              child: AnimatedContainer(
                duration: 150.ms,
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _unit == u ? AppTheme.yellow : AppTheme.surfaceHigh,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _unit == u ? AppTheme.yellow : AppTheme.divider),
                ),
                child: Text(u, style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: _unit == u ? Colors.black : AppTheme.grey)),
              ),
            )).toList()),
        const SizedBox(height: 14),

        // ── All conversions ───────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(color: AppTheme.surfaceHigh, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            for (final e in [
              ('mm', widget.cm * 10, 0),
              ('cm', widget.cm, 1),
              ('in', widget.cm / 2.54, 2),
              ('ft', widget.cm / 30.48, 3),
              ('m', widget.cm / 100, 3),
            ])
              Expanded(child: Column(children: [
                Text(e.$2.toStringAsFixed(e.$3),
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                Text(e.$1, style: GoogleFonts.inter(fontSize: 9, color: AppTheme.grey, letterSpacing: 0.5)),
              ])),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Label ─────────────────────────────────────────────────────────────
        TextField(
          controller: _label,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            labelText: 'Label',
            labelStyle: GoogleFonts.inter(color: AppTheme.grey, fontSize: 13),
            prefixIcon: const Icon(Icons.label_outline_rounded, color: AppTheme.grey, size: 18),
            filled: true, fillColor: AppTheme.surfaceHigh,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.divider)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.yellow, width: 1.5)),
          ),
        ),
        const SizedBox(height: 14),

        // ── Buttons ───────────────────────────────────────────────────────────
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: widget.onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16, color: AppTheme.grey),
            label: Text('Retry', style: GoogleFonts.inter(color: AppTheme.grey, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              side: const BorderSide(color: AppTheme.divider),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          )),
          const SizedBox(width: 10),
          _IconBtn(Icons.share_rounded, widget.onShare),
        ]),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: () {
            widget.onSave(_label.text.trim().isEmpty ? 'Measurement' : _label.text.trim());
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Saved!', style: GoogleFonts.inter(color: Colors.white)),
              backgroundColor: AppTheme.surfaceHigh, behavior: SnackBarBehavior.floating,
              duration: 1200.ms,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ));
          },
          icon: const Icon(Icons.bookmark_rounded, size: 18),
          label: Text('Save Measurement', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.yellow, foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
            elevation: 0),
        )),
      ])),
    ).animate().slideY(begin: 0.25, duration: 320.ms, curve: Curves.easeOutCubic);
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn(this.icon, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Icon(icon, color: AppTheme.grey, size: 20),
    ),
  );
}
