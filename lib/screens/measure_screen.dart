
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/app_theme.dart';

class MeasureScreen extends StatefulWidget {
  const MeasureScreen({super.key});

  @override
  State<MeasureScreen> createState() => _MeasureScreenState();
}

class _MeasureScreenState extends State<MeasureScreen> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];

  Offset? _pointA;
  Offset? _pointB;

  double _distanceCm = 0;
  bool _cameraReady = false;
  bool _measured = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final status = await Permission.camera.request();

    if (!status.isGranted) {
      return;
    }

    _cameras = await availableCameras();

    _cameraController = CameraController(
      _cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _cameraController!.initialize();

    if (mounted) {
      setState(() {
        _cameraReady = true;
      });
    }
  }

  void _onTap(TapDownDetails details) {
    final pos = details.localPosition;

    setState(() {
      if (_pointA == null) {
        _pointA = pos;
        _pointB = null;
        _measured = false;
      } else {
        _pointB = pos;
        _distanceCm = _calculateDistance(_pointA!, _pointB!);
        _measured = true;
      }
    });
  }

  double _calculateDistance(Offset a, Offset b) {
    final pixelDistance = sqrt(
      pow(b.dx - a.dx, 2) + pow(b.dy - a.dy, 2),
    );

    // Better calibrated approximation
    return pixelDistance * 0.12;
  }

  Widget _buildMarker(Offset point, Color color) {
    return Positioned(
      left: point.dx - 12,
      top: point.dy - 12,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    );
  }

  Widget _buildMeasurementLine() {
    if (_pointA == null || _pointB == null) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      painter: LinePainter(_pointA!, _pointB!),
      size: Size.infinite,
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: !_cameraReady
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : GestureDetector(
              onTapDown: _onTap,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CameraPreview(_cameraController!),
                  ),

                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppTheme.primaryBlue.withOpacity(0.4),
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  if (_pointA != null)
                    _buildMarker(_pointA!, Colors.green),

                  if (_pointB != null)
                    _buildMarker(_pointB!, Colors.red),

                  _buildMeasurementLine(),

                  Positioned(
                    top: 60,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        _measured
                            ? 'Measured Distance: ${_distanceCm.toStringAsFixed(1)} cm'
                            : 'Tap two points to measure object',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class LinePainter extends CustomPainter {
  final Offset start;
  final Offset end;

  LinePainter(this.start, this.end);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    canvas.drawLine(start, end, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
