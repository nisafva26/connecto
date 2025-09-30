// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:mapbox_gl/mapbox_gl.dart';

// // Your Mapbox access token
// const String mapboxAccessToken = 'YOUR_MAPBOX_ACCESS_TOKEN';

// Future<List<LatLng>> getRoute(LatLng userLocation, LatLng destination) async {
//   final url = 'https://api.mapbox.com/directions/v5/mapbox/driving-traffic/'
//       '${userLocation.longitude},${userLocation.latitude};'
//       '${destination.longitude},${destination.latitude}'
//       '?alternatives=false&geometries=geojson&steps=false&access_token=$mapboxAccessToken';

//   try {
//     final response = await http.get(Uri.parse(url));
//     if (response.statusCode == 200) {
//       final json = jsonDecode(response.body);
//       final routes = json['routes'] as List;
//       if (routes.isNotEmpty) {
//         final geometry = routes[0]['geometry']['coordinates'] as List;
//         return geometry
//             .map((coord) => LatLng(coord[1], coord[0]))
//             .toList();
//       }
//     }
//   } catch (e) {
//     print('Error fetching route: $e');
//   }
//   return [];
// }