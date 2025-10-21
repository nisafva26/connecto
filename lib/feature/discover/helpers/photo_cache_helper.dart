import 'dart:developer';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

final placePhotoCache = CacheManager(
  Config(
    'placePhotoCache',
    stalePeriod: const Duration(days: 30), // allowed client-side
    maxNrOfCacheObjects: 500,              // bump to reduce eviction
  ),
);

// build a stable URL + cacheKey per size
String placePhotoUrl(String photoRef, {int width = 200, required String apiKey}) =>
  'https://maps.googleapis.com/maps/api/place/photo?maxwidth=$width&photoreference=$photoRef&key=$apiKey';

String placePhotoCacheKey(String photoRef, {int width = 200}) =>
  'place_photo_${photoRef}_w$width';


Future<void> debugCheckCache(String url, String cacheKey) async {
  final fileInfo = await placePhotoCache.getFileFromCache(cacheKey);

  if (fileInfo != null) {
   log("CACHE HIT for $cacheKey → local file: ${fileInfo.file.path}");
  } else {
   log("CACHE MISS for $cacheKey → will trigger network call");
  }
}