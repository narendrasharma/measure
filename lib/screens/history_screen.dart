import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_theme.dart';
import '../utils/measurement_storage.dart';
import '../models/measurement.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Measurement> _measurements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await MeasurementStorage.loadAll();
    if (mounted) setState(() { _measurements = list; _loading = false; });
  }

  Future<void> _delete(String id) async {
    await MeasurementStorage.delete(id);
    _load();
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Clear All?',
            style: GoogleFonts.spaceGrotesk(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
        content: Text('This will delete all saved measurements.',
            style: GoogleFonts.spaceGrotesk(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.spaceGrotesk(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete All',
                style:
                    GoogleFonts.spaceGrotesk(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await MeasurementStorage.clearAll();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.accent))
                  : _measurements.isEmpty
                      ? _buildEmpty()
                      : _buildList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.divider),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppTheme.textPrimary, size: 18),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('History',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              Text('${_measurements.length} measurements saved',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
          const Spacer(),
          if (_measurements.isNotEmpty)
            GestureDetector(
              onTap: _clearAll,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                ),
                child: Text('Clear All',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        color: AppTheme.error,
                        fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: _measurements.length,
      itemBuilder: (_, i) {
        final m = _measurements[i];
        return Dismissible(
          key: Key(m.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.error.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete_rounded, color: AppTheme.error),
          ),
          onDismissed: (_) => _delete(m.id),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.accentGlow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.straighten_rounded,
                      color: AppTheme.accent, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.label,
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary)),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(m.createdAt),
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 11, color: AppTheme.textDim),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      m.displayString,
                      style: GoogleFonts.orbitron(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accent),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(m.unit.toUpperCase(),
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 9,
                              color: AppTheme.textDim,
                              letterSpacing: 1)),
                    ),
                  ],
                ),
              ],
            ),
          ).animate(delay: Duration(milliseconds: i * 60)).fadeIn(duration: 300.ms).slideX(begin: 0.05),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.straighten_rounded,
              color: AppTheme.textDim, size: 64),
          const SizedBox(height: 16),
          Text('No measurements yet',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Text('Start measuring to see results here',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 13, color: AppTheme.textDim)),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/measure',
                arguments: {'mode': 'ar'}),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.accent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text('Start Measuring',
                  style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.background)),
            ),
          ),
        ],
      ).animate().fadeIn(duration: 500.ms),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
