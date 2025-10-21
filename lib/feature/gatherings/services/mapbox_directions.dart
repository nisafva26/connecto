import 'dart:developer';

import 'package:http/http.dart' as http; // Make sure you import http
import 'dart:convert';

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
// ... other imports

// Function to fetch route geometry from Mapbox Directions API
Future<List<Position>?> fetchRoute(
    double startLng, double startLat, double endLng, double endLat) async {
  // Use a public access token for the Directions API call
  const String mapboxAccessToken = 'pk.eyJ1IjoibmlzYWZ2YSIsImEiOiJjbThoM2h5dmcwdnV3MmtvaXFidXhtb3gzIn0.59ykk4I9gCbLASEyxjIyvw'; 
  const String profile = 'driving'; // or 'walking', 'cycling'

  final String url =
      'https://api.mapbox.com/directions/v5/mapbox/$profile/$startLng,$startLat;$endLng,$endLat'
      '?alternatives=false&geometries=geojson&steps=false&access_token=$mapboxAccessToken';

  try {
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final features = data['routes'][0]['geometry']['coordinates'] as List;

      // Convert GeoJSON coordinates (Lng, Lat) to map.Point list
      return features.map((coord) {
        // Mapbox GeoJSON is [Longitude, Latitude]
        return  Position(coord[0], coord[1]);
      }).toList();
    } else {
      log('Mapbox Directions API failed: ${response.statusCode}');
      return null;
    }
  } catch (e, st) {
    log('Error fetching route: $e', stackTrace: st);
    return null;
  }
}