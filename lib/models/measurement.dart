import 'dart:convert';

class MeasurementPoint {
  final double x;
  final double y;
  final double z;

  const MeasurementPoint(this.x, this.y, this.z);

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'z': z};

  factory MeasurementPoint.fromJson(Map<String, dynamic> json) =>
      MeasurementPoint(json['x'], json['y'], json['z']);
}

class Measurement {
  final String id;
  final String label;
  final double widthCm;
  final double? heightCm;
  final double? depthCm;
  final DateTime createdAt;
  final String? imagePath;
  final String unit; // 'cm' or 'in'

  const Measurement({
    required this.id,
    required this.label,
    required this.widthCm,
    this.heightCm,
    this.depthCm,
    required this.createdAt,
    this.imagePath,
    this.unit = 'cm',
  });

  double get widthDisplay =>
      unit == 'in' ? widthCm / 2.54 : widthCm;

  double? get heightDisplay =>
      heightCm != null ? (unit == 'in' ? heightCm! / 2.54 : heightCm) : null;

  double? get depthDisplay =>
      depthCm != null ? (unit == 'in' ? depthCm! / 2.54 : depthCm) : null;

  String get unitLabel => unit == 'in' ? '"' : ' cm';

  String get displayString {
    final w = widthDisplay.toStringAsFixed(1);
    if (heightCm != null && depthCm != null) {
      final h = heightDisplay!.toStringAsFixed(1);
      final d = depthDisplay!.toStringAsFixed(1);
      return '$w × $h × $d$unitLabel';
    } else if (heightCm != null) {
      final h = heightDisplay!.toStringAsFixed(1);
      return '$w × $h$unitLabel';
    }
    return '$w$unitLabel';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'widthCm': widthCm,
        'heightCm': heightCm,
        'depthCm': depthCm,
        'createdAt': createdAt.toIso8601String(),
        'imagePath': imagePath,
        'unit': unit,
      };

  factory Measurement.fromJson(Map<String, dynamic> json) => Measurement(
        id: json['id'],
        label: json['label'],
        widthCm: json['widthCm'],
        heightCm: json['heightCm'],
        depthCm: json['depthCm'],
        createdAt: DateTime.parse(json['createdAt']),
        imagePath: json['imagePath'],
        unit: json['unit'] ?? 'cm',
      );
}
