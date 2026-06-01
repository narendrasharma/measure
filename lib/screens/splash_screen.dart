import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Background grid
          CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _GridPainter(),
          ),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo icon
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.accent, width: 2),
                    borderRadius: BorderRadius.circular(24),
                    color: AppTheme.accentGlow,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withOpacity(0.3),
                        blurRadius: 32,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.straighten_rounded,
                    color: AppTheme.accent,
                    size: 48,
                  ),
                )
                    .animate()
                    .scale(
                      begin: const Offset(0.5, 0.5),
                      duration: 600.ms,
                      curve: Curves.elasticOut,
                    )
                    .fadeIn(duration: 400.ms),

                const SizedBox(height: 28),

                // App name
                Text(
                  'DimScan',
                  style: GoogleFonts.orbitron(
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: 4,
                  ),
                )
                    .animate(delay: 300.ms)
                    .slideY(begin: 0.3, duration: 600.ms, curve: Curves.easeOut)
                    .fadeIn(duration: 500.ms),

                const SizedBox(height: 8),

                Text(
                  'PRECISION MEASUREMENT',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.accent,
                    letterSpacing: 4,
                  ),
                )
                    .animate(delay: 500.ms)
                    .fadeIn(duration: 600.ms),

                const SizedBox(height: 56),

                // Loading bar
                SizedBox(
                  width: 160,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      backgroundColor: AppTheme.surfaceElevated,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                      minHeight: 2,
                    ),
                  ),
                ).animate(delay: 700.ms).fadeIn(duration: 400.ms),
              ],
            ),
          ),

          // Version tag
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              'v1.0.0  •  AR POWERED',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                color: AppTheme.textDim,
                letterSpacing: 2,
              ),
            ).animate(delay: 800.ms).fadeIn(duration: 600.ms),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.accent.withOpacity(0.04)
      ..strokeWidth = 1;

    const step = 40.0;

    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
