import 'dart:convert';
import 'package:connecto/feature/gatherings/models/catoegory_places.dart';
import 'package:shared_preferences/shared_preferences.dart';


class PlacesCacheHelper {
  static const String _prefix = "discover_places_cache";

  /// Quantize lat/lng to ~1km bucket to reuse results
  static String _bucket(double lat, double lng) {
    double r2(double v) => (v * 100).round() / 100.0;
    return '${r2(lat)},${r2(lng)}';
  }

  static String buildKey({
    required List<String> categories,
    required double lat,
    required double lng,
    required int radius,
    required int maxPerCategory,
  }) {
    final b = _bucket(lat, lng);
    return '$_prefix:${categories.join("|")}:$b:$radius:$maxPerCategory';
  }

  /// Save cache
  static Future<void> save(
    String key,
    List<CategoryPlaces> data,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'at': DateTime.now().toIso8601String(),
      'data': data.map((c) => c.toJson()).toList(),
    };
    await prefs.setString(key, jsonEncode(payload));
  }

  /// Load cache if not expired
  static Future<List<CategoryPlaces>?> load(
    String key, {
    required Duration ttl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;

    final map = jsonDecode(raw) as Map<String, dynamic>;
    final at = DateTime.tryParse(map['at'] as String? ?? '');
    if (at == null) return null;
    if (DateTime.now().difference(at) > ttl) return null;

    final list = (map['data'] as List)
        .map((e) => CategoryPlaces.fromJson(e))
        .toList();
    return list;
  }
}
