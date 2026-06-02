import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_theme.dart';
import '../utils/measurement_storage.dart';
import '../models/measurement.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Measurement> _recent = [];

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final all = await MeasurementStorage.loadAll();
    if (mounted) {
      setState(() => _recent = all.take(3).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildModeCards(),
              const SizedBox(height: 32),
              _buildQuickStats(),
              const SizedBox(height: 32),
              if (_recent.isNotEmpty) _buildRecentSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DimScan',
              style: GoogleFonts.orbitron(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Measure anything with your camera',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        const Spacer(),
        _iconButton(
          icon: Icons.history_rounded,
          onTap: () async {
            await Navigator.pushNamed(context, '/history');
            _loadRecent();
          },
        ),
      ],
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.1);
  }

  Widget _buildModeCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('MEASUREMENT MODES'),
        const SizedBox(height: 16),
        _ModeCard(
          title: 'AR Measure',
          subtitle: 'Point & tap to measure real-world distances using augmented reality',
          icon: Icons.view_in_ar_rounded,
          badge: 'RECOMMENDED',
          badgeColor: AppTheme.accent,
          features: const ['Live AR overlay', 'Tap 2 points', 'Auto plane detection'],
          onTap: () => Navigator.pushNamed(
            context,
            '/measure',
            arguments: {'mode': 'ar'},
          ).then((_) => _loadRecent()),
        ).animate(delay: 100.ms).fadeIn(duration: 500.ms).slideX(begin: -0.05),

        const SizedBox(height: 14),

        _ModeCard(
          title: 'Reference Object',
          subtitle: 'Place a known object (coin, card) to calibrate and measure anything',
          icon: Icons.compare_arrows_rounded,
          badge: 'ALL DEVICES',
          badgeColor: AppTheme.success,
          features: const ['No AR required', 'Use coin/card ref', 'Photo capture'],
          onTap: () => Navigator.pushNamed(
            context,
            '/measure',
            arguments: {'mode': 'reference'},
          ).then((_) => _loadRecent()),
        ).animate(delay: 200.ms).fadeIn(duration: 500.ms).slideX(begin: -0.05),

        const SizedBox(height: 14),

        _ModeCard(
          title: 'Height Sensor',
          subtitle: 'Use accelerometer & gravity to measure object height from a distance',
          icon: Icons.height_rounded,
          badge: 'SENSOR',
          badgeColor: AppTheme.warning,
          features: const ['Tilt-based calc', 'No touch needed', 'Tall objects'],
          onTap: () => Navigator.pushNamed(
            context,
            '/measure',
            arguments: {'mode': 'height'},
          ).then((_) => _loadRecent()),
        ).animate(delay: 300.ms).fadeIn(duration: 500.ms).slideX(begin: -0.05),
      ],
    );
  }

  Widget _buildQuickStats() {
    return FutureBuilder<List<Measurement>>(
      future: MeasurementStorage.loadAll(),
      builder: (context, snap) {
        final count = snap.data?.length ?? 0;
        return Row(
          children: [
            _StatTile(label: 'Saved', value: '$count', icon: Icons.bookmark_rounded),
            const SizedBox(width: 12),
            _StatTile(label: 'Modes', value: '3', icon: Icons.tune_rounded),
            const SizedBox(width: 12),
            _StatTile(label: 'Accuracy', value: '±2mm', icon: Icons.gps_fixed_rounded),
          ],
        );
      },
    ).animate(delay: 400.ms).fadeIn(duration: 500.ms);
  }

  Widget _buildRecentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _sectionLabel('RECENT'),
            const Spacer(),
            GestureDetector(
              onTap: () async {
                await Navigator.pushNamed(context, '/history');
                _loadRecent();
              },
              child: Text(
                'SEE ALL →',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._recent.map((m) => _RecentTile(measurement: m)),
      ],
    ).animate(delay: 500.ms).fadeIn(duration: 500.ms);
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.spaceGrotesk(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppTheme.textDim,
        letterSpacing: 2,
      ),
    );
  }

  Widget _iconButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Icon(icon, color: AppTheme.textSecondary, size: 20),
      ),
    );
  }
}

// ─── Mode Card ─────────────────────────────────────────────────────────────

class _ModeCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String badge;
  final Color badgeColor;
  final List<String> features;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.badge,
    required this.badgeColor,
    required this.features,
    required this.onTap,
  });

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _pressed ? widget.badgeColor.withOpacity(0.5) : AppTheme.divider,
            ),
            boxShadow: _pressed
                ? [
                    BoxShadow(
                      color: widget.badgeColor.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 2,
                    )
                  ]
                : [],
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: widget.badgeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: widget.badgeColor.withOpacity(0.3)),
                ),
                child: Icon(widget.icon, color: widget.badgeColor, size: 28),
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.title,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: widget.badgeColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.badge,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: widget.badgeColor,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 12,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      children: widget.features
                          .map(
                            (f) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceElevated,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                f,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 10,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textDim,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Stat Tile ──────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatTile(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.accent, size: 18),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.orbitron(
                fontSize: 18,
                fontWeight: FontWeight.w700,
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
      ),
    );
  }
}

// ─── Recent Tile ────────────────────────────────────────────────────────────

class _RecentTile extends StatelessWidget {
  final Measurement measurement;

  const _RecentTile({required this.measurement});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.accentGlow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.straighten_rounded,
                color: AppTheme.accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  measurement.label,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  _timeAgo(measurement.createdAt),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    color: AppTheme.textDim,
                  ),
                ),
              ],
            ),
          ),
          Text(
            measurement.displayString,
            style: GoogleFonts.orbitron(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.accent,
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
