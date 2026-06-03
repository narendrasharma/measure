import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/measurement.dart';
import '../../core/theme/app_theme.dart';
import '../measure/measure_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Measurement> _recent = [];

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final all = await MeasurementStore.all();
    if (mounted) setState(() => _recent = all.take(3).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Measure', style: GoogleFonts.inter(
                  fontSize: 32, fontWeight: FontWeight.w300, color: Colors.white, letterSpacing: -1)),
                Text('Point. Tap. Measure.',
                  style: GoogleFonts.inter(fontSize: 13, color: AppTheme.grey)),
              ]),
              const Spacer(),
              _iconBtn(Icons.history_rounded, () async {
                await Navigator.pushNamed(context, '/history');
                _load();
              }),
            ]).animate().fadeIn(duration: 400.ms),
          ),

          const SizedBox(height: 28),

          // ── Mode grid ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              // Ruler (primary — big card)
              _BigCard(
                title: 'Ruler',
                desc: 'Drag to measure any distance',
                icon: Icons.straighten_rounded,
                color: AppTheme.yellow,
                onTap: () => _openMeasure(MeasureMode.ruler),
              ).animate(delay: 60.ms).fadeIn().slideY(begin: 0.05),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _SmallCard(
                  title: 'Area',
                  icon: Icons.crop_free_rounded,
                  color: AppTheme.blue,
                  onTap: () => _openMeasure(MeasureMode.area),
                ).animate(delay: 120.ms).fadeIn().slideY(begin: 0.05)),
                const SizedBox(width: 10),
                Expanded(child: _SmallCard(
                  title: 'Level',
                  icon: Icons.water_rounded,
                  color: AppTheme.green,
                  onTap: () => _openMeasure(MeasureMode.level),
                ).animate(delay: 160.ms).fadeIn().slideY(begin: 0.05)),
                const SizedBox(width: 10),
                Expanded(child: _SmallCard(
                  title: 'Height',
                  icon: Icons.height_rounded,
                  color: const Color(0xFFFF9500),
                  onTap: () => _openMeasure(MeasureMode.height),
                ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.05)),
              ]),
            ]),
          ),

          const SizedBox(height: 28),

          // ── Recent ───────────────────────────────────────────────────────
          if (_recent.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(children: [
                Text('RECENT', style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: AppTheme.grey, letterSpacing: 1.5)),
                const Spacer(),
                GestureDetector(
                  onTap: () async { await Navigator.pushNamed(context, '/history'); _load(); },
                  child: Text('See All', style: GoogleFonts.inter(
                    fontSize: 11, color: AppTheme.yellow, fontWeight: FontWeight.w500)),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            Expanded(child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _recent.length,
              separatorBuilder: (_, __) => const SizedBox(height: 1),
              itemBuilder: (_, i) => _RecentRow(_recent[i])
                  .animate(delay: (i * 50 + 250).ms).fadeIn(),
            )),
          ] else
            Expanded(child: Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.straighten_rounded, color: AppTheme.greyDark, size: 48),
                const SizedBox(height: 12),
                Text('No measurements yet', style: GoogleFonts.inter(color: AppTheme.grey)),
              ],
            ))),
        ]),
      ),
    );
  }

  void _openMeasure(MeasureMode mode) async {
    HapticFeedback.selectionClick();
    await Navigator.push(context,
      MaterialPageRoute(builder: (_) => const MeasureScreen(),
        settings: RouteSettings(arguments: {'mode': mode.name})));
    _load();
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: AppTheme.surface, borderRadius: BorderRadius.circular(20)),
      child: Icon(icon, color: AppTheme.grey, size: 18),
    ),
  );
}

class _BigCard extends StatelessWidget {
  final String title, desc;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _BigCard({required this.title, required this.desc, required this.icon,
    required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: color.withAlpha(22), borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withAlpha(60)),
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
          Text(desc, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.grey)),
        ])),
        Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.grey, size: 14),
      ]),
    ),
  );
}

class _SmallCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _SmallCard({required this.title, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: AppTheme.surface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(height: 8),
        Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
      ]),
    ),
  );
}

class _RecentRow extends StatelessWidget {
  final Measurement m;
  const _RecentRow(this.m);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: AppTheme.surface, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.divider),
    ),
    margin: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: AppTheme.yellow.withAlpha(22), borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.straighten_rounded, color: AppTheme.yellow, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(m.label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
        Text(_ago(m.createdAt), style: GoogleFonts.inter(fontSize: 11, color: AppTheme.grey)),
      ])),
      Text(m.formatted(m.unit), style: GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.yellow)),
    ]),
  );

  String _ago(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inHours < 1)   return '${d.inMinutes}m ago';
    if (d.inDays < 1)    return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}
