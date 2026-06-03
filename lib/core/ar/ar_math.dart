import 'dart:math';
import 'package:flutter/material.dart';

// ─── Vector3 ────────────────────────────────────────────────────────────────
class Vec3 {
  final double x, y, z;
  const Vec3(this.x, this.y, this.z);
  static const zero = Vec3(0, 0, 0);

  Vec3 operator +(Vec3 b) => Vec3(x + b.x, y + b.y, z + b.z);
  Vec3 operator -(Vec3 b) => Vec3(x - b.x, y - b.y, z - b.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);

  double get length => sqrt(x * x + y * y + z * z);
  Vec3 get normalized {
    final l = length;
    return l == 0 ? zero : Vec3(x / l, y / l, z / l);
  }

  double dot(Vec3 b) => x * b.x + y * b.y + z * b.z;
  Vec3 cross(Vec3 b) => Vec3(y * b.z - z * b.y, z * b.x - x * b.z, x * b.y - y * b.x);

  /// Euclidean distance to another point.
  double distanceTo(Vec3 b) => (b - this).length;

  @override
  String toString() => 'Vec3(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)}, ${z.toStringAsFixed(2)})';
}

// ─── AR Camera Model ─────────────────────────────────────────────────────────
/// Simulates the ARKit/ARCore camera model using device sensors.
/// Coordinate space: Y-up world, camera sitting at (0, height, 0) looking
/// slightly downward (forward = −Z in camera space).
class ARCamera {
  /// Screen size for principal-point calculation.
  final Size screen;

  /// Focal length in pixels (estimated from FoV).
  final double fl;

  /// Camera height above the measured surface (cm). Default 50 = table.
  double heightCm;

  /// Device pitch in radians (forward tilt). From accelerometer.
  double pitchRad;

  /// Device roll in radians. From accelerometer.
  double rollRad;

  ARCamera({
    required this.screen,
    required this.fl,
    this.heightCm = 50.0,
    this.pitchRad = 0.4,
    this.rollRad  = 0.0,
  });

  double get cx => screen.width  / 2;
  double get cy => screen.height / 2;

  /// Unprojects screen pixel → world ray (unit vector).
  Vec3 screenRay(Offset p) {
    final dx = p.dx - cx, dy = -(p.dy - cy);
    return _camToWorld(Vec3(dx, dy, fl).normalized);
  }

  /// Intersects ray with the ground plane Y = 0.
  /// Camera origin is at (0, heightCm, 0).
  Vec3? hitGround(Offset screen) {
    final ray = screenRay(screen);
    if (ray.y.abs() < 1e-4) return null;   // parallel to plane
    final t = -heightCm / ray.y;
    if (t < 0) return null;                 // behind camera
    return Vec3(ray.x * t, 0, ray.z * t);
  }

  /// Projects a world point to screen coordinates.
  Offset? projectToScreen(Vec3 world) {
    final cam = _worldToCam(world);
    if (cam.z <= 0) return null;
    return Offset(cam.x / cam.z * fl + cx, -cam.y / cam.z * fl + cy);
  }

  // ── Private rotation helpers ──────────────────────────────────────────────

  /// Camera space → world space (apply device tilt).
  Vec3 _camToWorld(Vec3 v) {
    // Pitch around X
    final cp = cos(pitchRad), sp = sin(pitchRad);
    final p = Vec3(v.x, v.y * cp - v.z * sp, v.y * sp + v.z * cp);
    // Roll around Z
    final cr = cos(rollRad), sr = sin(rollRad);
    return Vec3(p.x * cr - p.y * sr, p.x * sr + p.y * cr, p.z);
  }

  /// World space → camera space.
  Vec3 _worldToCam(Vec3 w) {
    final shifted = Vec3(w.x, w.y - heightCm, w.z);
    final cr = cos(-rollRad), sr = sin(-rollRad);
    final r = Vec3(shifted.x * cr - shifted.y * sr, shifted.x * sr + shifted.y * cr, shifted.z);
    final cp = cos(-pitchRad), sp = sin(-pitchRad);
    return Vec3(r.x, r.y * cp - r.z * sp, r.y * sp + r.z * cp);
  }

  /// Estimate focal length from screen height (assumes ~65° vertical FoV).
  static double estimateFL(double screenHeight) => screenHeight / (2 * tan(65 * pi / 360));
}

// ─── Measurement Point ────────────────────────────────────────────────────────
class ARHitPoint {
  final Vec3 world;
  final Offset screen;
  ARHitPoint(this.world, this.screen);
}

// ─── Formatting ───────────────────────────────────────────────────────────────
String fmtCm(double cm, String unit) => switch (unit) {
  'mm' => '${(cm * 10).toStringAsFixed(0)} mm',
  'm'  => '${(cm / 100).toStringAsFixed(3)} m',
  'in' => '${(cm / 2.54).toStringAsFixed(2)} in',
  'ft' => "${(cm / 30.48).toStringAsFixed(2)} ft",
  _    => '${cm.toStringAsFixed(1)} cm',
};

/// Compute polygon area in cm² using shoelace on XZ plane.
double polygonArea(List<Vec3> pts) {
  if (pts.length < 3) return 0;
  double area = 0;
  for (int i = 0; i < pts.length; i++) {
    final j = (i + 1) % pts.length;
    area += pts[i].x * pts[j].z - pts[j].x * pts[i].z;
  }
  return area.abs() / 2;
}
