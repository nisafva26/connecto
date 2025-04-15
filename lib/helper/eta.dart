 import 'dart:developer';

import 'package:geolocator/geolocator.dart';

Future<int> calculateETA(
    double userLat, double userLng, double eventLat, double eventLng) async {
  double distanceInMeters = Geolocator.distanceBetween(
    userLat,
    userLng,
    eventLat,
    eventLng,
  );

  

  double distanceInKm = distanceInMeters / 1000;

  log('distance in kms : $distanceInKm');
  const averageSpeedKmph = 40;

  double etaMinutes = (distanceInKm / averageSpeedKmph) * 60;
  return etaMinutes.round();
}
