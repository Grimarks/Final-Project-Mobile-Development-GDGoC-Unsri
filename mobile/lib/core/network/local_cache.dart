import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

// cache offline biar dashboard gak kosong pas sinyal jelek. cuma buat baca ya,
// gaada antrean tulis offline
class LocalCache {
  static const _boxName = 'campusflow_cache';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<String>(_boxName);
  }

  static Box<String> get _box => Hive.box<String>(_boxName);

  static Future<void> putList(String key, List<dynamic> value) =>
      _box.put(key, jsonEncode(value));

  static List<dynamic>? getList(String key) {
    final raw = _box.get(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() => _box.clear();
}
