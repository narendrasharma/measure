import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_theme.dart';

class MeasurementResultSheet extends StatefulWidget {
  final double distanceCm;
  final String mode;
  final String unit;
  final ValueChanged<String> onUnitToggle;
  final ValueChanged<String> onSave;
  final VoidCallback onRetry;

  const MeasurementResultSheet({
    super.key,
    required this.distanceCm,
    required this.mode,
    required this.unit,
    required this.onUnitToggle,
    required this.onSave,
    required this.onRetry,
  });

  @override
  State<MeasurementResultSheet> createState() =>
      _MeasurementResultSheetState();
}

class _MeasurementResultSheetState extends State<MeasurementResultSheet> {
  late String _unit;
  final _labelController = TextEditingController(text: 'Measurement');

  @override
  void initState() {
    super.initState();
    _unit = widget.unit;
  }

  double get _display =>
      _unit == 'cm' ? widget.distanceCm : widget.distanceCm / 2.54;

  String get _displayStr =>
      _unit == 'cm'
          ? '${_display.toStringAsFixed(1)} cm'
          : '${_display.toStringAsFixed(2)} in';

  double get _displayMm => widget.distanceCm * 10;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: AppTheme.textDim,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Result
          _buildResult(),

          const SizedBox(height: 24),

          // Conversions
          _buildConversions(),

          const SizedBox(height: 20),

          // Label input
          _buildLabelInput(),

          const SizedBox(height: 20),

          // Actions
          _buildActions(),
        ],
      ),
    ).animate().slideY(begin: 0.3, duration: 400.ms, curve: Curves.easeOut);
  }

  Widget _buildResult() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Measurement Result',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                color: AppTheme.textDim,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Big number
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          decoration: BoxDecoration(
            color: AppTheme.accentGlow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withOpacity(0.15),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _unit == 'cm'
                    ? _display.toStringAsFixed(1)
                    : _display.toStringAsFixed(2),
                style: GoogleFonts.orbitron(
                  fontSize: 52,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accent,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _unit,
                  style: GoogleFonts.orbitron(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.accentDim,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Unit toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _UnitChip(
              label: 'CM',
              selected: _unit == 'cm',
              onTap: () {
                setState(() => _unit = 'cm');
                widget.onUnitToggle('cm');
              },
            ),
            const SizedBox(width: 8),
            _UnitChip(
              label: 'INCHES',
              selected: _unit == 'in',
              onTap: () {
                setState(() => _unit = 'in');
                widget.onUnitToggle('in');
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConversions() {
    final mm = _displayMm;
    final inches = widget.distanceCm / 2.54;
    final feet = inches / 12;
    final m = widget.distanceCm / 100;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'UNIT CONVERSIONS',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10,
              color: AppTheme.textDim,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _ConvTile(label: 'mm', value: mm.toStringAsFixed(0)),
              _ConvTile(label: 'cm', value: widget.distanceCm.toStringAsFixed(1)),
              _ConvTile(label: 'in', value: inches.toStringAsFixed(2)),
              _ConvTile(label: 'ft', value: feet.toStringAsFixed(3)),
              _ConvTile(label: 'm', value: m.toStringAsFixed(3)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLabelInput() {
    return TextField(
      controller: _labelController,
      style: GoogleFonts.spaceGrotesk(
          color: AppTheme.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: 'Label this measurement',
        labelStyle: GoogleFonts.spaceGrotesk(
            color: AppTheme.textDim, fontSize: 13),
        prefixIcon: const Icon(Icons.label_outline_rounded,
            color: AppTheme.textDim, size: 20),
        filled: true,
        fillColor: AppTheme.surfaceElevated,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppTheme.accent, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        // Retry
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              widget.onRetry();
            },
            icon: const Icon(Icons.refresh_rounded,
                size: 18, color: AppTheme.textSecondary),
            label: Text('Retry',
                style: GoogleFonts.spaceGrotesk(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppTheme.divider),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Copy
        IconButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _displayStr));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Copied: $_displayStr',
                    style: GoogleFonts.spaceGrotesk(
                        color: AppTheme.textPrimary)),
                backgroundColor: AppTheme.surface,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          icon: const Icon(Icons.copy_rounded, color: AppTheme.textSecondary),
          style: IconButton.styleFrom(
            backgroundColor: AppTheme.surfaceElevated,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.all(14),
          ),
        ),

        const SizedBox(width: 12),

        // Save
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: () {
              final label = _labelController.text.trim().isEmpty
                  ? 'Measurement'
                  : _labelController.text.trim();
              widget.onSave(label);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.bookmark_rounded, size: 18),
            label: Text('Save',
                style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w700, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: AppTheme.background,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Helper Widgets ─────────────────────────────────────────────────────────

class _UnitChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _UnitChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent : AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.accent : AppTheme.divider,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? AppTheme.background : AppTheme.textSecondary,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _ConvTile extends StatelessWidget {
  final String label;
  final String value;

  const _ConvTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.orbitron(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10,
              color: AppTheme.textDim,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
