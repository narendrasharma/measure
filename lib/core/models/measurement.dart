import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// A saved measurement entry.
class Measurement {
  final String id;
  final String label;
  final double primaryCm;     // main dimension
  final double? secondaryCm;  // height (area mode)
  final double? areaCm2;
  final String mode;          // 'ruler' | 'area' | 'level' | 'height'
  final String unit;
  final DateTime createdAt;

  const Measurement({
    required this.id,
    required this.label,
    required this.primaryCm,
    this.secondaryCm,
    this.areaCm2,
    required this.mode,
    required this.unit,
    required this.createdAt,
  });

  String formatted(String u) {
    final v = _convert(primaryCm, u);
    return '${v.toStringAsFixed(u == 'mm' ? 0 : 1)} $u';
  }

  static double _convert(double cm, String u) => switch (u) {
    'mm' => cm * 10,
    'm'  => cm / 100,
    'in' => cm / 2.54,
    'ft' => cm / 30.48,
    _    => cm,
  };

  Map<String, dynamic> toJson() => {
    'id': id, 'label': label, 'primaryCm': primaryCm,
    'secondaryCm': secondaryCm, 'areaCm2': areaCm2,
    'mode': mode, 'unit': unit, 'createdAt': createdAt.toIso8601String(),
  };

  factory Measurement.fromJson(Map<String, dynamic> j) => Measurement(
    id: j['id'], label: j['label'], primaryCm: j['primaryCm'],
    secondaryCm: j['secondaryCm'], areaCm2: j['areaCm2'],
    mode: j['mode'] ?? 'ruler', unit: j['unit'] ?? 'cm',
    createdAt: DateTime.parse(j['createdAt']),
  );
}

class MeasurementStore {
  static const _key = 'v4_measurements';

  static Future<List<Measurement>> all() async {
    final p = await SharedPreferences.getInstance();
    return (p.getStringList(_key) ?? [])
        .map((e) => Measurement.fromJson(jsonDecode(e)))
        .toList()
        .reversed.toList();
  }

  static Future<void> save(Measurement m) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_key) ?? [];
    raw.add(jsonEncode(m.toJson()));
    await p.setStringList(_key, raw);
  }

  static Future<void> delete(String id) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_key) ?? [];
    raw.removeWhere((e) => jsonDecode(e)['id'] == id);
    await p.setStringList(_key, raw);
  }

  static Future<void> clearAll() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
  }
}
