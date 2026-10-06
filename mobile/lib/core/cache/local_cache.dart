import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheEntry {
  final Map<String, dynamic> data;
  final DateTime cachedAt;

  CacheEntry({required this.data, required this.cachedAt});

  factory CacheEntry.fromJson(Map<String, dynamic> json) {
    return CacheEntry(
      data: json['data'] as Map<String, dynamic>,
      cachedAt: DateTime.parse(json['cachedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'data': data,
      'cachedAt': cachedAt.toIso8601String(),
    };
  }

  bool get isExpired {
    final now = DateTime.now();
    final difference = now.difference(cachedAt);
    return difference.inDays > 7;
  }
}

class LocalCache {
  static const String _prefix = 'naatal_cache_';
  final SharedPreferences _prefs;
  final String _userId;

  LocalCache(this._prefs, this._userId);

  String _buildKey(String key) {
    return '$_prefix${_userId}_$key';
  }

  Future<void> write(String key, Map<String, dynamic> data) async {
    final entry = CacheEntry(data: data, cachedAt: DateTime.now());
    await _prefs.setString(_buildKey(key), jsonEncode(entry.toJson()));
  }

  Future<CacheEntry?> read(String key) async {
    final jsonStr = _prefs.getString(_buildKey(key));
    if (jsonStr == null) return null;

    try {
      final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
      final entry = CacheEntry.fromJson(jsonMap);

      if (entry.isExpired) {
        await delete(key);
        return null;
      }

      return entry;
    } catch (e) {
      // In case of corruption
      await delete(key);
      return null;
    }
  }

  Future<void> delete(String key) async {
    await _prefs.remove(_buildKey(key));
  }

  Future<void> clearUserCache() async {
    final keys = _prefs.getKeys();
    final userPrefix = '$_prefix${_userId}_';
    for (final key in keys) {
      if (key.startsWith(userPrefix)) {
        await _prefs.remove(key);
      }
    }
  }
}
