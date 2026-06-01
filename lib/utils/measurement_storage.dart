import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/measurement.dart';

class MeasurementStorage {
  static const _key = 'measurements';

  static Future<List<Measurement>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((e) => Measurement.fromJson(jsonDecode(e)))
        .toList()
        .reversed
        .toList();
  }

  static Future<void> save(Measurement m) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.add(jsonEncode(m.toJson()));
    await prefs.setStringList(_key, raw);
  }

  static Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.removeWhere((e) => jsonDecode(e)['id'] == id);
    await prefs.setStringList(_key, raw);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
