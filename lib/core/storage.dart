import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Сохранение прогресса. Ключ и структура JSON совпадают с веб-версией
/// (`synapse_v1`), чтобы формат оставался единым и документированным.
class Storage {
  Storage._();
  static final Storage instance = Storage._();

  static const _key = 'synapse_v1';
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Map<String, dynamic>? load() {
    final raw = _prefs?.getString(_key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  void save(Map<String, dynamic> data) {
    _prefs?.setString(_key, jsonEncode(data));
  }

  void reset() {
    _prefs?.remove(_key);
  }
}
