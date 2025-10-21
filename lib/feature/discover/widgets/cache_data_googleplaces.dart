import 'dart:math';

import 'package:connecto/feature/gatherings/models/catoegory_places.dart';
import 'package:geolocator/geolocator.dart';

/// Keep results in memory for this run. (You can persist with Hive/SharedPreferences if you want.)
class _PlacesCacheEntry {
  final DateTime at;
  final List<CategoryPlaces> data;
  _PlacesCacheEntry(this.at, this.data);
}

class PlacesCache {
  static final PlacesCache _i = PlacesCache._();
  PlacesCache._();
  factory PlacesCache() => _i;

  final _mem = <String, _PlacesCacheEntry>{};

  String _bucket(double lat, double lng) {
    // Round to ~1km buckets to avoid re-fetching for tiny moves
    double r2(double v) => (v * 100).round() / 100.0;
    return '${r2(lat)},${r2(lng)}';
  }

  String key({
    required List<String> categories,
    required double lat,
    required double lng,
    required int radius,
    required int maxPerCategory,
  }) {
    final bucket = _bucket(lat, lng);
    return 'cats=${categories.join("|")};loc=$bucket;rad=$radius;max=$maxPerCategory';
  }

  List<CategoryPlaces>? get(String key, Duration ttl) {
    final e = _mem[key];
    if (e == null) return null;
    if (DateTime.now().difference(e.at) > ttl) return null;
    return e.data;
  }

  void put(String key, List<CategoryPlaces> data) {
    _mem[key] = _PlacesCacheEntry(DateTime.now(), data);
  }
}