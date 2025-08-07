import 'dart:async';
import 'dart:developer';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:connecto/common_widgets/continue_button.dart';
import 'package:connecto/feature/discover/screens/select_location_discover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_google_maps_webservices/places.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_rating_stars/flutter_rating_stars.dart';
import 'package:go_router/go_router.dart';
import 'package:loading_indicator/loading_indicator.dart';
import 'package:shimmer/shimmer.dart';

class LocationDetailsScreen extends StatefulWidget {
  final String activty;
  final PlacesSearchResult placesSearchResult;
  final bool shouldShowConfirmButton;
  LocationDetailsScreen(
      {super.key,
      required this.placesSearchResult,
      required this.activty,
      this.shouldShowConfirmButton = true});

  @override
  State<LocationDetailsScreen> createState() => _LocationDetailsScreenState();
}

class _LocationDetailsScreenState extends State<LocationDetailsScreen> {
  int currentPage = 0;
  late final PageController _pageController;
  Timer? _autoSwipeTimer;

  PlaceDetails? placeDetails;
  bool isLoading = true;
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    fetchDetails();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _autoSwipeTimer?.cancel();
    super.dispose();
  }

  final _places = GoogleMapsPlaces(apiKey: googleApiKey);

  Future<PlaceDetails?> fetchPlaceDetails(String placeId) async {
    final response = await _places.getDetailsByPlaceId(placeId);
    if (response.isOkay) {
      return response.result;
    }
    return null;
  }

  Future<void> fetchDetails() async {
    final response =
        await _places.getDetailsByPlaceId(widget.placesSearchResult.placeId);
    if (response.isOkay && mounted) {
      setState(() {
        placeDetails = response.result;
        isLoading = false;
        _hasAnimated = true;
      });

      // ✅ Start auto-swipe now that photos are available
      final total = placeDetails?.photos.length ?? 0;
      if (total > 1) {
        _autoSwipeTimer = Timer.periodic(Duration(seconds: 4), (_) {
          if (!mounted) return;
          setState(() {
            currentPage = (currentPage + 1) % total;
            _pageController.animateToPage(
              currentPage,
              duration: Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          });
        });
      }
    } else {
      setState(() {
        _hasAnimated = true;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    log('image length : ${widget.placesSearchResult}');
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
      body: isLoading
          ?
          // Center(
          //     child: SizedBox(
          //       height: 40,
          //       child: LoadingIndicator(
          //         indicatorType: Indicator.ballBeat,
          //         colors: [Colors.white],
          //       ),
          //     ),
          //   )
          Shimmer.fromColors(
              baseColor: Colors.grey[800]!,
              highlightColor: Colors.grey[600]!,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: MediaQuery.of(context).size.height / 2.7,
                    width: double.infinity,
                    color: Colors.grey[800],
                  ),
                  SizedBox(height: 30),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: List.generate(
                          3,
                          (_) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Container(
                                  height: 20,
                                  width: double.infinity,
                                  color: Colors.grey[800],
                                ),
                              )),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 20, top: 16),
                    child: Shimmer.fromColors(
                      baseColor: Colors.grey[800]!,
                      highlightColor: Colors.grey[700]!,
                      child: SizedBox(
                        height: 135,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: 3,
                          separatorBuilder: (_, __) => SizedBox(width: 16),
                          itemBuilder: (context, index) {
                            return Container(
                              width: index == 0 ? 130 : 250,
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(12),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  )
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // if (isLoading)
                //   Container(
                //     height: 260,
                //     child: Center(child: CircularProgressIndicator()),
                //   )
                if (placeDetails == null || placeDetails!.photos.isEmpty)
                  Container(
                    height: 260,
                    color: Colors.grey,
                    child: Center(child: Text('No images found')),
                  )
                else
                  Stack(
                    children: [
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height / 2.7,
                        width: double.infinity,
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() {
                              currentPage = index;
                            });
                          },
                          itemCount: placeDetails!.photos.length,
                          itemBuilder: (context, index) {
                            final photoRef =
                                placeDetails!.photos[index].photoReference;
                            return CachedNetworkImage(
                              imageUrl:
                                  'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=$photoRef&key=$googleApiKey',
                              fit: BoxFit.cover,
                              fadeInDuration: Duration(milliseconds: 300),
                              placeholderFadeInDuration:
                                  Duration(milliseconds: 100),
                              placeholder: (context, url) => Container(
                                color: Colors
                                    .grey[900], // Soft color instead of spinner
                              ),
                              errorWidget: (_, __, ___) => Icon(Icons.error),
                            );
                          },
                        ),
                      ),

                      /// 🔹 Rectangle Page Indicator
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: Row(
                          children: List.generate(
                            placeDetails!.photos.length,
                            (index) => AnimatedContainer(
                              duration: Duration(milliseconds: 300),
                              width: currentPage == index ? 20 : 12,
                              height: 6,
                              margin: EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: currentPage == index
                                    ? Theme.of(context).colorScheme.secondary
                                    : Theme.of(context)
                                        .colorScheme
                                        .secondary
                                        .withOpacity(0.4),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                SizedBox(
                  height: 41,
                ),
                Animate(
                  effects: [
                    SlideEffect(
                      begin: Offset(0, 0.2),
                      end: Offset.zero,
                      duration: Duration(milliseconds: 700),
                      curve: Curves.easeOut,
                    ),
                    FadeEffect(duration: Duration(milliseconds: 900)),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.placesSearchResult.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontFamily: 'SFPRO',
                            fontWeight: FontWeight.w700,
                            height: 0.85,
                          ),
                        ),
                        SizedBox(height: 20),
                        Row(
                          spacing: 9,
                          children: [
                            Icon(Icons.location_on, color: Colors.grey),
                            Expanded(
                              child: Text(
                                widget.placesSearchResult.formattedAddress!,
                                style: TextStyle(
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
                ).animate(
                  target: _hasAnimated ? 1 : 0,
                ),

                /// 🔹 Rating and Reviews Section
                if (placeDetails != null && placeDetails!.reviews.isNotEmpty)
                  Container(
                    height: 135,
                    padding: EdgeInsets.only(left: 20),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 1 + placeDetails!.reviews.take(5).length,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Container(
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
                                  placeDetails!.rating?.toStringAsFixed(1) ??
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
                                      placeDetails!.rating!.toDouble(),
                                  minRating: 1,
                                  direction: Axis.horizontal,
                                  allowHalfRating: true,
                                  itemCount: 5,
                                  itemSize: 15,
                                  itemBuilder: (context, _) => Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                  ),
                                  onRatingUpdate: (_) {},
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '${placeDetails!.reviews.length}+ ratings',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.white),
                                ),
                              ],
                            ),
                          );
                        } else {
                          final review = placeDetails!.reviews[index - 1];
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

                Spacer(),
                if (widget.shouldShowConfirmButton)
                  Padding(
                    padding: const EdgeInsets.all(20.0).copyWith(bottom: 40),
                    child: ContinueButton(
                      onPressed: () {
                        context.push(
                          '/gathering/create-gathering-circle',
                          extra: {
                            'activity': widget.activty, // String?
                            'place': widget.placesSearchResult,
                            'shouldPop' : false
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
