import 'dart:async';
import 'dart:developer';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:connecto/feature/discover/widgets/horizontal_location_card.dart';
import 'package:connecto/feature/discover/widgets/location_card.dart';
import 'package:connecto/feature/discover/widgets/location_search_card_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as map;
import 'package:flutter_google_maps_webservices/places.dart';

class SearchMarkerInfo {
  final map.PointAnnotation annotation;
  final map.PointAnnotationOptions options;

  SearchMarkerInfo({required this.annotation, required this.options});
}

enum SheetState { sheetMode, fullMapMode }

// final ValueNotifier<bool> showHorizontalCards = ValueNotifier(false);

final ValueNotifier<SheetState> sheetState =
    ValueNotifier(SheetState.sheetMode);

final googleApiKey = dotenv.env['GOOGLE_API_KEY'];

class SelectLocationScreen extends StatefulWidget {
  final String eventType;

  SelectLocationScreen({required this.eventType});

  @override
  _SelectLocationScreenState createState() => _SelectLocationScreenState();
}

class _SelectLocationScreenState extends State<SelectLocationScreen>
    with WidgetsBindingObserver {
  // Replace with your key
  GoogleMapsPlaces places = GoogleMapsPlaces(apiKey: googleApiKey);

  final DraggableScrollableController draggableController =
      DraggableScrollableController();

  final PageController _pageController = PageController(
    viewportFraction: 0.90,
    initialPage: 0,
  );

  SheetState currentState = SheetState.sheetMode;
  PlacesSearchResult? selectedPlaceLocal;

  bool showHorizontalCards = false;
  bool isLoadingSuggestions = true;

  final Map<String, SearchMarkerInfo> searchPlaceMarkers = {};

  map.MapboxMap? mapboxMap;
  map.Point? selectedLocation;
  String? selectedPlace;
  List<PlacesSearchResult> suggestedPlaces = [];
  TextEditingController searchController = TextEditingController();
  PlacesSearchResult? selectedSearchResult;

  Timer? _debounce;
  map.PointAnnotationManager? annotationManager;

  map.PointAnnotationManager? currentPositionManager;

  map.PointAnnotationManager? searchAnnotationManager;

  map.CircleAnnotationManager? circleAnnotationManager;
  final ValueNotifier<double> sheetTop = ValueNotifier(350);

  GlobalKey labelKey = GlobalKey();

  String? selectedHeroPlaceId;

  bool showLottieIcon = true;

  Position? currentPosition;
  bool justCollapsedFromTap = false;

  String? selectedCategory = '';

  final List<Map<String, dynamic>> activityList = [
    {"name": "Football", "icon": Icons.sports_soccer},
    {"name": "Birthday", "icon": Icons.celebration},
    {"name": "Desert camping", "icon": Icons.terrain},
    {"name": "Padel Tennis", "icon": Icons.sports_tennis},
    {"name": "Coffee", "icon": Icons.local_cafe},
    {"name": "Sheesha Longue", "icon": FontAwesomeIcons.bong},
    {"name": "Other", "icon": Icons.group},
  ];

  Offset? screenPosition;

  void updateLottiePosition(double lat, double lng) async {
    final screenCoords = await mapboxMap?.pixelForCoordinate(
      map.Point(coordinates: map.Position(lng, lat)),
    );
    if (screenCoords != null) {
      setState(() {
        screenPosition = Offset(screenCoords.x, screenCoords.y);
      });
    }
  }

  void _onChanged() {
    final currentSize = draggableController.size;
    if (currentSize <= 0.05) _collapse();
  }

  void _collapse() => _animateSheet(sheet.snapSizes!.first);

  final _sheet = GlobalKey();

  double lastExtent = 0.5;

  void _animateSheet(double size) {
    draggableController.animateTo(
      size,
      duration: const Duration(milliseconds: 50),
      curve: Curves.easeInOut,
    );
  }

  void _onCameraChanged() async {
    if (selectedLocation != null) {
      final screenCoords =
          await mapboxMap!.pixelForCoordinate(selectedLocation!);
      if (screenCoords != null) {
        setState(() {
          screenPosition = Offset(screenCoords.x, screenCoords.y);
        });
      }
    }
  }



  DraggableScrollableSheet get sheet =>
      (_sheet.currentWidget as DraggableScrollableSheet);
  @override
  void initState() {
    super.initState();
    selectedCategory = widget.eventType;
    draggableController.addListener(_onChanged);

    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final position = await getCurrentPosition();

      // await Future.delayed(
      //     Duration(milliseconds: 400)); // match page transition
      draggableController.animateTo(
        0.6,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
      setState(() {
        currentPosition = position;
      });

      log('===current position : $position');

      fetchSuggestedLocations();
    });
  }

  Future<Position> getCurrentPosition() async {
    LocationPermission permission = await Geolocator.checkPermission();
    // Geolocator.requestPermission();
    log('permission : $permission');

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        throw Exception("Location permission not granted");
      }
    }
    final position = await Geolocator.getCurrentPosition();
    log('cur pos in fn : $position');
    return position;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// 🔹 Detect keyboard open/close and update UI
  @override
  void didChangeMetrics() {
    final bottomInset = View.of(context).viewInsets.bottom;
    if (mounted) {
      setState(() {
        sheetTop.value =
            bottomInset > 0 ? 150 : 350; // Move UI up when keyboard opens
      });
    }
  }

  /// 🔹 Fetch places based on event type
  Future<void> fetchSuggestedLocations() async {
    // log('event type : ${widget.eventType} ${searchController.text}');
    log('=========inside fetch suggestions....==========');

    log('current posotion : $currentPosition');
    final String query = searchController.text.isEmpty
        ? selectedCategory!
        : selectedCategory! +
            searchController.text; // Use event type or user input

    log('Fetching places for: $query');

    PlacesSearchResponse response = await places.searchByText(
      query,
      location: Location(
          lat: currentPosition!.latitude,
          lng: currentPosition!.longitude), // Example: Dubai Center
      radius: 100000, // 10km radius
    );

    log('==response : ${response.status}');

    if (currentPosition != null) {
      final markerImage = await _iconToImage(
        Icons.location_on,
        color: Colors.redAccent, // customize color
        size: 60, // customize size
      );

      await currentPositionManager?.create(map.PointAnnotationOptions(
        geometry: map.Point(
          coordinates: map.Position(
            currentPosition!.longitude,
            currentPosition!.latitude,
          ),
        ),
        image: markerImage,
        iconSize: 1.0,
      ));
    }

    if (response.isOkay) {
      setState(() {
        suggestedPlaces = response.results;
        isLoadingSuggestions = false;
      });

      searchAnnotationManager?.deleteAll(); // Clear previous markers

      for (int i = 0; i < suggestedPlaces.length; i++) {
        final place = suggestedPlaces[i];
        final lat = place.geometry!.location.lat;
        final lng = place.geometry!.location.lng;

        final markerImage = await _generateNumberedMarker(i + 1); // index + 1
        // final markerImage =
        //     await _generateNumberedMarkerWithLabel(i + 1, place.name);

        // searchAnnotationManager?.create(map.PointAnnotationOptions(
        //   geometry: map.Point(coordinates: map.Position(lng, lat)),
        //   image: markerImage,
        //   iconSize: 1.0,
        // ));

        final options = map.PointAnnotationOptions(
          geometry: map.Point(coordinates: map.Position(lng, lat)),
          image: markerImage,
          iconSize: 1.0,
        );

        final annotation = await searchAnnotationManager?.create(options);
        if (annotation != null && place.placeId != null) {
          searchPlaceMarkers[place.placeId!] = SearchMarkerInfo(
            annotation: annotation,
            options: options,
          );
        }
      }
      final place = suggestedPlaces[0];
      setState(() {
        selectedPlace = place.name;
      });
      selectLocation(
        place.geometry!.location.lat,
        place.geometry!.location.lng,
        place,
      );
    }
  }

    void handleMarkerTap(map.PointAnnotation annotation) {
    final tappedEntry = searchPlaceMarkers.entries.firstWhere(
      (entry) => entry.value.annotation.id == annotation.id,
    );

    if (tappedEntry != null) {
      final tappedPlaceId = tappedEntry.key;
      final tappedIndex = suggestedPlaces.indexWhere(
        (place) => place.placeId == tappedPlaceId,
      );

      if (tappedIndex != -1) {
        final tappedPlace = suggestedPlaces[tappedIndex];

        _pageController.animateToPage(
          tappedIndex,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );

        selectLocation(
          tappedPlace.geometry!.location.lat,
          tappedPlace.geometry!.location.lng,
          tappedPlace,
        );
      }
    }
  }

  /// 🔹 Select a location & update Mapbox
  void selectLocation(double lat, double lng, PlacesSearchResult place) async {
    // Load the image from assets
    log('selected place in capture widget .. ${place.name}');
    final ByteData bytes =
        await rootBundle.load('assets/images/location_marker.png');
    final Uint8List imageData = bytes.buffer.asUint8List();
    // Uint8List? labelImage = await _captureWidgetAsImage();
    setState(() {
      selectedLocation = map.Point(coordinates: map.Position(lng, lat));
      showLottieIcon = false;

      log('selected location : ${selectedLocation!.coordinates.lat}');

      // ✅ Step 2: Wait for the UI update before capturing image
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Uint8List? labelImage = await _captureWidgetAsImage();
        // if (labelImage != null) {
        // Move the camera
        mapboxMap?.flyTo(
          map.CameraOptions(
            center: selectedLocation!,
            zoom: 13.0,
          ),
          map.MapAnimationOptions(duration: 1500),
        );

        // ✅ Wait for the flyTo animation
        await Future.delayed(Duration(milliseconds: 1000));

        updateLottiePosition(lat, lng);

        if (selectedPlace != null &&
            selectedPlaceLocal?.placeId != place.placeId &&
            searchPlaceMarkers.containsKey(selectedPlaceLocal?.placeId)) {
          final old = searchPlaceMarkers[selectedPlaceLocal!.placeId]!;
          try {
            final restored = await searchAnnotationManager?.create(old.options);
            if (restored != null) {
              searchPlaceMarkers[selectedPlaceLocal!.placeId] =
                  SearchMarkerInfo(
                annotation: restored,
                options: old.options,
              );
            }
          } catch (e) {
            log("⚠️ Failed to restore marker: $e");
          }
        }

        // ✅ Step 5: Remove marker for current selected place
        final markerInfo = searchPlaceMarkers[place.placeId];
        if (markerInfo != null) {
          try {
            await searchAnnotationManager?.delete(markerInfo.annotation);
          } catch (e) {
            log("⚠️ Error deleting marker for selected place: $e");
          }
        }

        // Remove previous annotations
        circleAnnotationManager?.deleteAll();
        annotationManager?.deleteAll();

        // ✅ Update selected place
        selectedPlaceLocal = place;

        showLottieIcon = true;
      });
    });
  }

  /// Handles search input changes with debounce
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(Duration(milliseconds: 800), () {
      fetchSuggestedLocations();
    });
  }

  @override
  Widget build(BuildContext context) {
    // // log('current position : $currentPosition');
    // log('show horizontal card : $showHorizontalCards');
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        height: MediaQuery.of(context).size.height,
        padding: EdgeInsets.all(0),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            /// 🔹 Mapbox Map
            Container(
              height: MediaQuery.of(context).size.height,
              child: Stack(
                children: [
                  // Invisible widget to generate an image for the label
                  RepaintBoundary(
                    key: labelKey,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        selectedPlace ?? '',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ),
                  RepaintBoundary(
                    child: Container(
                      height: 800,
                      width: MediaQuery.sizeOf(context).width,
                      child: map.MapWidget(
                        onCameraChangeListener: (cameraChangedEventData) async {
                          if (selectedLocation != null && mapboxMap != null) {
                            final screenCoords = await mapboxMap!
                                .pixelForCoordinate(selectedLocation!);
                            if (screenCoords != null) {
                              setState(() {
                                screenPosition =
                                    Offset(screenCoords.x, screenCoords.y);
                              });
                            }
                          }
                        },
                        onTapListener: (context) {
                          log('inside map on tap');

                          setState(() {
                            currentState = SheetState.fullMapMode;
                            showHorizontalCards = true;
                          });
                          draggableController.animateTo(
                            0.01, // collapse
                            duration: Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        key: ValueKey(currentPosition),
                        cameraOptions: currentPosition == null
                            ? map.CameraOptions(
                                zoom: 10,
                                center: map.Point(
                                    coordinates: map.Position(
                                  55.296249,
                                  25.276987,
                                )))
                            : map.CameraOptions(
                                zoom: 10,
                                center: map.Point(
                                    coordinates: map.Position(
                                        currentPosition!.longitude,
                                        currentPosition!.latitude
                                        // 55.296249,
                                        // 25.276987,
                                        ))),
                        onMapCreated: (map) async {
                          setState(() {
                            mapboxMap = map;
                          });

                          // Initialize annotation manager for adding markers
                          annotationManager = await map.annotations
                              .createPointAnnotationManager();

                          // Initialize circle annotation manager
                          circleAnnotationManager = await map.annotations
                              .createCircleAnnotationManager();

                          searchAnnotationManager = await map.annotations
                              .createPointAnnotationManager();

                          currentPositionManager = await map.annotations
                              .createPointAnnotationManager();

                          // ✅ Attach the listener
                          searchAnnotationManager
                              ?.addOnPointAnnotationClickListener(
                            MyPointAnnotationClickListener(this),
                          );

                          // mapboxMap!.location
                          //     .updateSettings(LocationComponentSettings(
                          //   enabled: true,
                          //   pulsingEnabled: true,
                          // ));
                        },
                      ),
                    ),
                  ),

                  if (screenPosition != null && showLottieIcon)
                    Positioned(
                      left: screenPosition!.dx -
                          35, // center horizontally (width / 2)
                      top: screenPosition!.dy - 55,
                      // shift up to align pin tip (height)
                      child: SizedBox(
                        width: 70,
                        height: 70,
                        child: Lottie.asset(
                            'assets/lottie/office-location-pin.json'),
                      ),
                    ),

                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    bottom: showHorizontalCards
                        ? 220
                        : -180, // move off screen if false
                    left: 0,
                    right: 0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: showHorizontalCards ? 1.0 : 0.0,
                      child: Visibility(
                        visible: showHorizontalCards,
                        maintainState: true,
                        maintainAnimation: true,
                        child: Container(
                            height: 155,
                            child: PageView.builder(
                              padEnds: false,
                              controller: _pageController,
                              itemCount: suggestedPlaces.length,
                              onPageChanged: (index) {
                                final place = suggestedPlaces[index];

                                setState(() {
                                  selectedPlace = place.name;
                                });
                                selectLocation(
                                  place.geometry!.location.lat,
                                  place.geometry!.location.lng,
                                  place,
                                );
                              },
                              itemBuilder: (context, index) {
                                final place = suggestedPlaces[index];

                                return AnimatedBuilder(
                                  animation: _pageController,
                                  builder: (context, child) {
                                    // double value = 1.0;
                                    // if (_pageController
                                    //     .position.haveDimensions) {
                                    //   value =
                                    //       (_pageController.page! - index).abs();
                                    //   value = (1 - (value * 0.2))
                                    //       .clamp(0.85, 1.0); // scale effect
                                    // }

                                    return MinimalMapCard(
                                      place: place,
                                      currentPosition: currentPosition!,
                                      onTap: (selected) {
                                        context.push(
                                          '/location-details',
                                          extra: {
                                            'place': selected,
                                            'activity': widget.eventType,
                                          },
                                        );

                                        // _flyTo(selected.geometry!.location.lat, selected.geometry!.location.lng);
                                      },
                                    );
                                  },
                                );
                              },
                            )),
                      ),
                    ),
                  ),

                  /// 🔹 Animated Positioned Container (Smooth Transition)
                  NotificationListener<DraggableScrollableNotification>(
                    onNotification:
                        (DraggableScrollableNotification notification) {
                      final current = notification.extent;

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (showHorizontalCards &&
                              suggestedPlaces.isNotEmpty &&
                              mapboxMap != null) {
                            final place = suggestedPlaces[0];
                            setState(() {
                              selectedPlace = place.name;
                            });
                            selectLocation(
                              place.geometry!.location.lat,
                              place.geometry!.location.lng,
                              place,
                            );
                          }
                        });
                      });

                      // Determine drag direction
                      if (current > lastExtent) {
                        // log('🟢 Dragging up');

                        // ✅ Hide horizontal cards only when user is dragging up
                        if (showHorizontalCards) {
                          setState(() {
                            showHorizontalCards = false;
                          });
                        }
                      } else {
                        // log(' ====Dragging down=====');
                        if (showHorizontalCards == false) {
                          setState(() {
                            showHorizontalCards = true;
                          });
                        }
                      }

                      lastExtent = current;
                      return true;
                    },
                    child: DraggableScrollableSheet(
                        // initialChildSize: 0.5,
                        // minChildSize: 0.11,
                        initialChildSize: .4,
                        controller: draggableController,
                        snap: true,
                        expand: true,
                        maxChildSize: 1,
                        minChildSize: .2,
                        builder: (context, scrollController) {
                          return Container(
                            decoration: BoxDecoration(
                              color: Color(0xff001311), // Background color
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                              ),
                            ),
                            child: CustomScrollView(
                              controller: scrollController,
                              slivers: [
                                SliverPersistentHeader(
                                  pinned: true,
                                  delegate: _PinnedHeaderDelegate(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Color(
                                            0xff001311), // Background color
                                        borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(20),
                                          topRight: Radius.circular(20),
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                                vertical: 12)
                                            .copyWith(bottom: 0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            buildSheetHandle(context),
                                            const SizedBox(height: 26),
                                            buildSearchBar(),
                                            const SizedBox(height: 16),
                                            buildActivityChips(),
                                            // const SizedBox(height: 16),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SliverList.list(children: [
                                  isLoadingSuggestions
                                      ? ListView.builder(
                                          itemCount: 4,
                                          padding: EdgeInsets.only(top: 0),
                                          shrinkWrap: true,
                                          physics:
                                              NeverScrollableScrollPhysics(),
                                          itemBuilder: (_, __) =>
                                              const LocationSearchCardSkeleton(),
                                        )
                                      : ListView.builder(
                                          shrinkWrap: true,
                                          padding: EdgeInsets.only(top: 24),
                                          physics:
                                              NeverScrollableScrollPhysics(),
                                          // controller: scrollController,
                                          // physics: NeverScrollableScrollPhysics(),
                                          // Enable smooth scrolling
                                          itemCount: suggestedPlaces.length,
                                          itemBuilder: (context, index) {
                                            final place =
                                                suggestedPlaces[index];

                                            return LocationSearchCard(
                                              place: place,
                                              currentPosition: currentPosition!,
                                              selectedPlace:
                                                  selectedSearchResult,
                                              onTap: (selected) {
                                                context.push(
                                                  '/location-details',
                                                  extra: {
                                                    'place': selected,
                                                    'activity':
                                                        widget.eventType,
                                                  },
                                                );
                                              },
                                            );
                                          },
                                        ),
                                ])
                              ],
                            ),
                          );
                        }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Center buildSheetHandle(BuildContext context) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).hintColor,
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        height: 4,
        width: 40,
        margin: const EdgeInsets.symmetric(vertical: 10),
      ),
    );
  }

  Padding buildSearchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 23, vertical: 10)
          .copyWith(top: 0, bottom: 0),
      child: TextField(
        controller: searchController,
        onChanged: _onSearchChanged,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search, color: Colors.white),
          hintText: "Search for a location",
          hintStyle: TextStyle(color: Colors.grey),
          filled: true,
          fillColor: Color(0xff091F1E),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), // Rounded corners
            borderSide: BorderSide(
              color: Colors.white24, // Light border color
              width: 1,
            ),
          ),
          suffixIcon: Icon(Icons.search, color: Colors.grey),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Color(0xFF03FFE2), // Neon blue-green focus color
              width: 1,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Padding buildActivityChips() {
    return Padding(
      padding: const EdgeInsets.only(left: 23),
      child: Container(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          shrinkWrap: true,
          children: activityList.map((activity) {
            final bool isSelected = selectedCategory == activity['name'];

            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                avatar: Icon(
                  activity['icon'],
                  color: isSelected ? Color(0xFF03FFE2) : Colors.white,
                  size: 18,
                ),
                label: Text(
                  activity['name'],
                  style: TextStyle(
                    color: isSelected ? Color(0xFF03FFE2) : Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                selected: isSelected,
                backgroundColor: Color(0xff091F1E),
                selectedColor: Color(0xFF091F1E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isSelected ? Color(0xFF03FFE2) : Color(0xFF0E3735),
                  ),
                ),
                showCheckmark: false,
                onSelected: (_) {
                  setState(() {
                    selectedCategory = activity['name'];
                  });

                  // Optional: trigger re-fetch
                  fetchSuggestedLocations();
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Convert Flutter Widget to an Image for Custom Label
  Future<Uint8List?> _captureWidgetAsImage() async {
    RenderRepaintBoundary? boundary =
        labelKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    ui.Image image =
        await boundary.toImage(pixelRatio: 3.0); // High-resolution image
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }
}

class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _PinnedHeaderDelegate({required this.child});

  @override
  double get minExtent => 180; // adjust based on your content
  @override
  double get maxExtent => 180;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xff001311), // Background color
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}

Future<Uint8List> _generateNumberedMarker(int number) async {
  final PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  final Paint paint = Paint()..color = const Color(0xFF03FFE2);
  final double size = 60.0;

  final textPainter = TextPainter(
    text: TextSpan(
      text: number.toString(),
      style: TextStyle(
        color: Colors.black,
        fontSize: 26,
        fontWeight: FontWeight.bold,
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  textPainter.layout();

  canvas.drawCircle(Offset(size / 2, size / 2), size / 2, paint);
  textPainter.paint(
    canvas,
    Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
  );

  final img = await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

Future<Uint8List> _iconToImage(IconData iconData,
    {Color color = Colors.blue, double size = 48}) async {
  final PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);

  final icon = Icon(iconData, size: size, color: color);
  final RenderRepaintBoundary boundary = RenderRepaintBoundary();

  final textPainter = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: size,
        fontFamily: iconData.fontFamily,
        color: color,
        package: iconData.fontPackage,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  textPainter.paint(canvas, Offset.zero);

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

class MyPointAnnotationClickListener
    extends map.OnPointAnnotationClickListener {
  final _SelectLocationScreenState parent;

  MyPointAnnotationClickListener(this.parent);

  @override
  void onPointAnnotationClick(map.PointAnnotation annotation) {
    parent.handleMarkerTap(annotation);
  }
}
