import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class CrosshairWidget extends StatelessWidget {
  final Color color;
  final String label;

  const CrosshairWidget({
    super.key,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow ring
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.1),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ],
            ),
          ),

          // Outer ring
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
          ),

          // Center dot
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),

          // Label
          Positioned(
            top: -16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                label,
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().scale(
          begin: const Offset(0.3, 0.3),
          duration: 300.ms,
          curve: Curves.elasticOut,
        );
  }
}
