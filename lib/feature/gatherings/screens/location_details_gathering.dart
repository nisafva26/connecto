import 'dart:developer';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:connecto/common_widgets/continue_button.dart';
import 'package:connecto/feature/discover/screens/select_location_discover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_google_maps_webservices/places.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_rating_stars/flutter_rating_stars.dart';
import 'package:go_router/go_router.dart';

class LocationDetailsGatheringScreen extends StatelessWidget {
  final String activty;
  final PlacesSearchResult placesSearchResult;
  LocationDetailsGatheringScreen(
      {super.key, required this.placesSearchResult, required this.activty});

  final _places = GoogleMapsPlaces(apiKey: googleApiKey);

  Future<PlaceDetails?> fetchPlaceDetails(String placeId) async {
    final response = await _places.getDetailsByPlaceId(placeId);
    if (response.isOkay) {
      return response.result;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
          preferredSize: Size.fromHeight(80),
          child: Container(
            height: 100,
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20)
                  .copyWith(top: 50),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: Container(
                        height: 34,
                        width: 34,
                        // padding: const EdgeInsets.all(10),
                        decoration: ShapeDecoration(
                          color: const Color(0xFF03FFE2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                        child: Icon(
                          Icons.close,
                          color: Colors.black,
                          size: 20,
                        )),
                  ),
                ],
              ),
            ),
          )),
      extendBodyBehindAppBar: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          placesSearchResult.photos.isEmpty
              ? Container(
                  height: 260,
                  color: Colors.grey,
                )
              : CachedNetworkImage(
                  height: MediaQuery.sizeOf(context).height / 2.7,
                  fit: BoxFit.cover,
                  width: MediaQuery.sizeOf(context).width,
                  imageUrl:
                      'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=${placesSearchResult.photos.first.photoReference}&key=$googleApiKey',
                  placeholder: (context, url) =>
                      Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => Icon(Icons.error),
                ),
          SizedBox(
            height: 41,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  placesSearchResult.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontFamily: 'SFPRO',
                    fontWeight: FontWeight.w700,
                    height: 0.85,
                  ),
                ),
                SizedBox(
                  height: 20,
                ),
                Row(
                  spacing: 9,
                  children: [
                    Icon(
                      Icons.location_on,
                      color: Colors.grey,
                    ),
                    Expanded(
                      child: Text(
                        placesSearchResult.formattedAddress!,
                        style: TextStyle(
                          // color: Colors.white,
                          fontSize: 14,
                          fontFamily: 'SFPRO',
                          fontWeight: FontWeight.w400,
                          height: 1.57,
                        ),
                      ),
                    )
                  ],
                ),
                SizedBox(height: 30),
                Text(
                  'Ratings and reviews',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'SFPRO',
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
          FutureBuilder<PlaceDetails?>(
            future: fetchPlaceDetails(placesSearchResult.placeId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data == null) {
                return Text('No additional details found.');
              }

              final placeDetails = snapshot.data!;
              final reviews = placeDetails.reviews;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 12),
                  Container(
                    height: 135,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 1 +
                          (reviews.take(5).length ??
                              0), // 1 for rating + up to 5 reviews
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          // ⭐ Rating Card
                          return Padding(
                            padding: const EdgeInsets.only(left: 20),
                            child: Container(
                              width: 130,
                              margin: EdgeInsets.only(right: 16),
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.tertiary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    placeDetails.rating?.toStringAsFixed(1) ??
                                        'N/A',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  RatingBar.builder(
                                    initialRating:
                                        placeDetails.rating!.toDouble(),
                                    minRating: 1,
                                    direction: Axis.horizontal,
                                    allowHalfRating: true,
                                    itemCount: 5,
                                    itemSize: 15,
                                    // itemPadding:
                                    //     EdgeInsets.symmetric(horizontal: 4.0),
                                    itemBuilder: (context, _) => Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                    ),
                                    onRatingUpdate: (rating) {
                                      print(rating);
                                    },
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    '${reviews.length}+ ratings',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontFamily: 'Inter'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        } else {
                          // 💬 Review Cards
                          final review = reviews[
                              index - 1]; // -1 because index 0 is rating card
                          return Container(
                            width: 250,
                            margin: EdgeInsets.only(right: 16),
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.tertiary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  review.authorName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  review.text,
                                  style: TextStyle(
                                    color: Colors.grey[300],
                                    fontSize: 13,
                                    height: 1.4,
                                    //  fontFamily: 'Inter'
                                  ),
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          Spacer(),
          Padding(
            padding: const EdgeInsets.all(20.0).copyWith(bottom: 40),
            child: ContinueButton(
              onPressed: () {
                context.push(
                  '/gathering/create-gathering-circle',
                  extra: {
                    'activity': activty, // String?
                    'place': placesSearchResult,
                  },
                );
              },
              text: 'Confirm location',
              color: Theme.of(context).colorScheme.primary,
            ),
          )
        ],
      ),
    );
  }
}
