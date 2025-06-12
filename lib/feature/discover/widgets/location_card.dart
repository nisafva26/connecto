import 'package:connecto/feature/gatherings/screens/select_location_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_google_maps_webservices/places.dart';
import 'package:geolocator/geolocator.dart';

class LocationSearchCard extends StatelessWidget {
  final PlacesSearchResult place;
  final Position currentPosition;
  final PlacesSearchResult? selectedPlace;
  final Function(PlacesSearchResult) onTap;

  const LocationSearchCard({
    super.key,
    required this.place,
    required this.currentPosition,
    required this.selectedPlace,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final placeLat = place.geometry?.location.lat ?? 0;
    final placeLng = place.geometry?.location.lng ?? 0;

    final double distanceInMeters = Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      placeLat,
      placeLng,
    );

    final String distanceText =
        '${(distanceInMeters / 1000).toStringAsFixed(1)} Km away';

    return GestureDetector(
      onTap: () => onTap(place),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 23, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xff091F1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selectedPlace == place
                ? const Color(0xFF03FFE2)
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Cover Image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: place.photos.isNotEmpty
                  ? Image.network(
                      "https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=${place.photos.first.photoReference}&key=$googleApiKey",
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      height: 160,
                      width: double.infinity,
                      color: Colors.grey.shade800,
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_not_supported,
                          color: Colors.white54),
                    ),
            ),
            const SizedBox(height: 20),

            // ✅ Title
            Text(
              place.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontFamily: 'SFPRO',
                fontWeight: FontWeight.w700,
                height: 1.10,
              ),
            ),
            const SizedBox(height: 14),

            // ✅ Location + Distance
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    place.vicinity ?? place.formattedAddress ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  distanceText,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
