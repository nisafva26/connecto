import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:connecto/common_widgets/continue_button.dart';
import 'package:connecto/feature/discover/screens/select_location_discover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_google_maps_webservices/places.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:shimmer/shimmer.dart';

class LocationDetailsPopUp extends StatefulWidget {
  final String placeId;

  const LocationDetailsPopUp({
    super.key,
    required this.placeId,
  });

  @override
  State<LocationDetailsPopUp> createState() => _LocationDetailsPopUpState();
}

class _LocationDetailsPopUpState extends State<LocationDetailsPopUp> {
  final _places = GoogleMapsPlaces(apiKey: googleApiKey);
  final PageController _pageController = PageController();
  Timer? _autoSwipeTimer;

  PlaceDetails? placeDetails;
  bool isLoading = true;
  bool hasAnimated = false;
  int currentPage = 0;

  @override
  void initState() {
    super.initState();
    _fetchPlaceDetails();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _autoSwipeTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchPlaceDetails() async {
    final response = await _places.getDetailsByPlaceId(widget.placeId);
    if (response.isOkay && mounted) {
      placeDetails = response.result;
      _startAutoSwipe(placeDetails?.photos.length ?? 0);
    }
    if (mounted) {
      setState(() {
        isLoading = false;
        hasAnimated = true;
      });
    }
  }

  void _startAutoSwipe(int total) {
    if (total <= 1) return;
    _autoSwipeTimer = Timer.periodic(Duration(seconds: 4), (_) {
      if (!mounted) return;
      currentPage = (currentPage + 1) % total;
      _pageController.animateToPage(
        currentPage,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(80),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Align(
              alignment: Alignment.topRight,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                child: Container(
                  height: 34,
                  width: 34,
                  decoration: BoxDecoration(
                    color: Color(0xFF03FFE2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, color: Colors.black, size: 20),
                ),
              ),
            ),
          ),
        ),
      ),
      body: isLoading
          ? _buildShimmer()
          : placeDetails == null
              ? Center(child: Text('Failed to load place details'))
              : _buildContent(),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[600]!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              height: MediaQuery.of(context).size.height / 2.7,
              color: Colors.grey[800]),
          SizedBox(height: 30),
          ...List.generate(
              3,
              (_) => Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Container(height: 20, color: Colors.grey[800]),
                  )),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final photos = placeDetails!.photos;
    final reviews = placeDetails!.reviews;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        photos.isEmpty
            ? Container(
                height: 260,
                color: Colors.grey,
                child: Center(child: Text('No images')))
            : Stack(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height / 2.7,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: photos.length,
                      onPageChanged: (index) =>
                          setState(() => currentPage = index),
                      itemBuilder: (context, index) {
                        final photoRef = photos[index].photoReference;
                        final imageUrl =
                            'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=$photoRef&key=$googleApiKey';

                        return CachedNetworkImage(
                          imageUrl: imageUrl,
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
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Row(
                      children: List.generate(
                        photos.length,
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
        SizedBox(height: 41),
        Animate(
          target: hasAnimated ? 1 : 0,
          effects: [
            SlideEffect(
                begin: Offset(0, 0.2), end: Offset.zero, duration: 700.ms),
            FadeEffect(duration: 900.ms),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  placeDetails!.name,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.grey),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        placeDetails!.formattedAddress ?? '',
                        style: TextStyle(fontSize: 14, color: Colors.grey[300]),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 30),
                Text(
                  'Ratings and reviews',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
        ),
        if (reviews.isNotEmpty) _buildReviewsSection(),
        Spacer(),
        Padding(
          padding: const EdgeInsets.all(20).copyWith(bottom: 40),
          child: ContinueButton(
            text: 'Get directions',
            onPressed: () => Navigator.pop(context, placeDetails),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsSection() {
    final rating = placeDetails?.rating ?? 0;
    final reviews = placeDetails!.reviews;

    return SizedBox(
      height: 135,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 20),
        itemCount: 1 + reviews.length.clamp(0, 5),
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
                  Text(rating.toStringAsFixed(1),
                      style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  SizedBox(height: 8),
                  RatingBarIndicator(
                    rating: rating.toDouble(),
                    itemBuilder: (context, _) =>
                        Icon(Icons.star, color: Colors.amber),
                    itemCount: 5,
                    itemSize: 15,
                  ),
                  SizedBox(height: 8),
                  Text('${reviews.length}+ ratings',
                      style: TextStyle(fontSize: 12, color: Colors.white)),
                ],
              ),
            );
          } else {
            final review = reviews[index - 1];
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
                  Text(review.authorName,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white)),
                  SizedBox(height: 6),
                  Text(
                    review.text,
                    style: TextStyle(
                        color: Colors.grey[300], fontSize: 13, height: 1.4),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}

//  Navigator.of(context).pop(widget.placesSearchResult);
