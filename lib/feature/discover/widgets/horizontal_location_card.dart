import 'package:connecto/feature/discover/screens/select_location_discover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_google_maps_webservices/places.dart';
import 'package:geolocator/geolocator.dart';

class MinimalMapCard extends StatelessWidget {
  final PlacesSearchResult place;
  final Position currentPosition;
  final Function(PlacesSearchResult) onTap;

  const MinimalMapCard({
    Key? key,
    required this.place,
    required this.currentPosition,
    required this.onTap,
  }) : super(key: key);

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
        '${(distanceInMeters / 1000).toStringAsFixed(1)} km';

    return GestureDetector(
      onTap: () => onTap(place),
      child: Container(
        width: 320,
        height: 150,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.all(16),
        decoration: ShapeDecoration(
          color: const Color(0xFF091F1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          children: [
            // Left Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    maxLines: 2,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          place.vicinity ?? place.formattedAddress ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xff9DA5A5),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 12, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        distanceText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xff9DA5A5),
                        ),
                      ),
                    ],
                  ),

                  // Text(
                  //   place.types.isNotEmpty
                  //       ? place.types.first.replaceAll('_', ' ')
                  //       : "Place",
                  //   style: const TextStyle(fontSize: 13, color: Colors.black),
                  // ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Image with heart icon
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: place.photos.isNotEmpty
                  ? Image.network(
                      "https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=${place.photos.first.photoReference}&key=$googleApiKey",
                      height: 200,
                      width: 100,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      height: 80,
                      width: 80,
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.image_not_supported),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
