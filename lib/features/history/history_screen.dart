import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/measurement.dart';
import '../../core/theme/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Measurement> _items = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final all = await MeasurementStore.all();
    if (mounted) setState(() { _items = all; _loading = false; });
  }

  Future<void> _delete(String id) async {
    await MeasurementStore.delete(id);
    _load();
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Clear All?', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
        content: Text('This will permanently delete all saved measurements.',
          style: GoogleFonts.inter(color: AppTheme.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: Text('Clear All', style: GoogleFonts.inter(color: AppTheme.red, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (ok == true) { await MeasurementStore.clearAll(); _load(); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        title: Text('Saved', style: GoogleFonts.inter(
          color: Colors.white, fontWeight: FontWeight.w300, fontSize: 22)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context)),
        actions: [
          if (_items.isNotEmpty)
            TextButton(onPressed: _clearAll,
              child: Text('Clear', style: GoogleFonts.inter(color: AppTheme.red, fontWeight: FontWeight.w500))),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.yellow, strokeWidth: 2))
        : _items.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.bookmark_border_rounded, color: AppTheme.greyDark, size: 52),
              const SizedBox(height: 12),
              Text('No saved measurements', style: GoogleFonts.inter(color: AppTheme.grey)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (_, i) => Dismissible(
                key: Key(_items[i].id),
                direction: DismissDirection.endToStart,
                onDismissed: (_) { HapticFeedback.mediumImpact(); _delete(_items[i].id); },
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.red.withAlpha(25),
                    borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.delete_outline_rounded, color: AppTheme.red)),
                child: _HistoryCard(_items[i]).animate(delay: (i * 30).ms).fadeIn(),
              ),
            ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Measurement m;
  const _HistoryCard(this.m);

  @override
  Widget build(BuildContext context) {
    final modeColor = switch (m.mode) {
      'area'   => AppTheme.blue,
      'level'  => AppTheme.green,
      'height' => const Color(0xFFFF9500),
      _        => AppTheme.yellow,
    };
    final modeIcon = switch (m.mode) {
      'area'   => Icons.crop_free_rounded,
      'level'  => Icons.water_rounded,
      'height' => Icons.height_rounded,
      _        => Icons.straighten_rounded,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: modeColor.withAlpha(22), borderRadius: BorderRadius.circular(12),
            border: Border.all(color: modeColor.withAlpha(60)),
          ),
          child: Icon(modeIcon, color: modeColor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m.label, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white)),
          const SizedBox(height: 2),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: modeColor.withAlpha(18), borderRadius: BorderRadius.circular(6)),
              child: Text(m.mode.toUpperCase(), style: GoogleFonts.inter(
                fontSize: 8, fontWeight: FontWeight.w700, color: modeColor, letterSpacing: 1)),
            ),
            const SizedBox(width: 8),
            Text(_fmt(m.createdAt), style: GoogleFonts.inter(fontSize: 10, color: AppTheme.grey)),
          ]),
          if (m.areaCm2 != null) ...[
            const SizedBox(height: 4),
            Text('Area: ${m.areaCm2!.toStringAsFixed(1)} cm²',
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.grey)),
          ],
        ])),
        Text(m.formatted(m.unit), style: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w600, color: modeColor)),
      ]),
    );
  }

  String _fmt(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inHours < 1)   return '${d.inMinutes}m ago';
    if (d.inDays < 1)    return '${d.inHours}h ago';
    if (d.inDays < 7)    return '${d.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
