import 'dart:developer';

import 'package:http/http.dart' as http;
import 'dart:convert';

Future<int> calculateMapboxETA({
  required double userLat,
  required double userLng,
  required double eventLat,
  required double eventLng,
}) async {
  final token =
      'pk.eyJ1IjoibmlzYWZ2YSIsImEiOiJjbThoM2h5dmcwdnV3MmtvaXFidXhtb3gzIn0.59ykk4I9gCbLASEyxjIyvw';

  final url =
      'https://api.mapbox.com/directions/v5/mapbox/driving/$userLng,$userLat;$eventLng,$eventLat?access_token=$token&overview=false';

  final response = await http.get(Uri.parse(url));

  // log('mapbox response : ${response.toString()}');

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final durationInSeconds = data['routes'][0]['duration'];
    final distanceInMeters = data['routes'][0]['distance'];
    final summary = data['routes'][0]['legs'][0]['summary'];
    final etaMinutes = (durationInSeconds / 60).round();

    print('🛣️ Route: $summary');
    print('⏱️ ETA: $etaMinutes min');
    print('📏 Distance: ${(distanceInMeters / 1000).toStringAsFixed(2)} km');

    return etaMinutes;
  } else {
    throw Exception('Failed to fetch ETA');
  }
}
