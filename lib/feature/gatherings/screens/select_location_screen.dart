import 'dart:async';
import 'dart:developer';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:connecto/common_widgets/continue_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as map;
import 'package:flutter_google_maps_webservices/places.dart';
import 'package:google_places_flutter/google_places_flutter.dart';

final String googleApiKey =
// "AIzaSyDQDygEMbAATTuNLiqFjnP7uNXwVfWgc4Y";
    "AIzaSyBNzf-57rbmFgIcx7gtlalr0wtpMmJaltQ";

class AddLocationScreen extends StatefulWidget {
  final String eventType;

  AddLocationScreen({required this.eventType});

  @override
  _AddLocationScreenState createState() => _AddLocationScreenState();
}

class _AddLocationScreenState extends State<AddLocationScreen>
    with WidgetsBindingObserver {
  // Replace with your key
  GoogleMapsPlaces places = GoogleMapsPlaces(apiKey: googleApiKey);

  map.MapboxMap? mapboxMap;
  map.Point? selectedLocation;
  String? selectedPlace;
  List<PlacesSearchResult> suggestedPlaces = [];
  TextEditingController searchController = TextEditingController();
  PlacesSearchResult? selectedSearchResult;

  Timer? _debounce;
  map.PointAnnotationManager? annotationManager;
  map.CircleAnnotationManager? circleAnnotationManager;
  final ValueNotifier<double> sheetTop = ValueNotifier(350);

  GlobalKey labelKey = GlobalKey();

  Position? currentPosition;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final position = await getCurrentPosition();
      setState(() {
        currentPosition = position;
      });

      fetchSuggestedLocations();
    });
  }

  Future<Position> getCurrentPosition() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        throw Exception("Location permission not granted");
      }
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
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

    log('current posotion : $currentPosition');
    final String query = searchController.text.isEmpty
        ? widget.eventType
        : widget.eventType +
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

    if (response.isOkay) {
      setState(() {
        suggestedPlaces = response.results;
      });
    }
  }

  /// 🔹 Select a location & update Mapbox
  void selectLocation(double lat, double lng, PlacesSearchResult place) async {
    // Load the image from assets
    final ByteData bytes =
        await rootBundle.load('assets/images/location_marker.png');
    final Uint8List imageData = bytes.buffer.asUint8List();
    // Uint8List? labelImage = await _captureWidgetAsImage();
    setState(() {
      selectedLocation = map.Point(coordinates: map.Position(lng, lat));

      log('selected location : ${selectedLocation!.coordinates.lat}');

      // ✅ Step 2: Wait for the UI update before capturing image
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        Uint8List? labelImage = await _captureWidgetAsImage();
        if (labelImage != null) {
          // Move the camera
          mapboxMap?.flyTo(
            map.CameraOptions(
              center: selectedLocation!,
              zoom: 13.0,
            ),
            map.MapAnimationOptions(duration: 1500),
          );

          // Remove previous annotations
          circleAnnotationManager?.deleteAll();
          annotationManager?.deleteAll();
          circleAnnotationManager?.create(map.CircleAnnotationOptions(
            geometry: selectedLocation!,
            circleRadius: 14, // Circle size
            circleColor: 0xff03FFE2, // Circle color
            circleStrokeWidth: 1,
            circleStrokeColor: 0xff000000,
          ));

          // ✅ Add Label as an Image using PointAnnotation
          annotationManager?.create(map.PointAnnotationOptions(
            geometry: map.Point(
              coordinates: map.Position(
                  selectedLocation!.coordinates.lng,
                  selectedLocation!.coordinates.lat -
                      0.0029 // Offset label below the marker
                  ),
            ),
            image: labelImage,
            iconSize: 1.0, // Keep size original
          )
          );
        }
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
    // log('current position : $currentPosition');
    return DraggableScrollableSheet(
        initialChildSize: 0.9, // Take 90% of the screen
        minChildSize: 0.9, // Minimum height
        maxChildSize: .9,
        builder: (context, scrollController) {
          return Container(
            // height: MediaQuery.of(context).size.height,
            padding: EdgeInsets.all(0),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8)
                      .copyWith(right: 20),
                  decoration: BoxDecoration(
                    color: Color(0xff091F1E),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text("Cancel",
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.primary)),
                      ),
                      Spacer(),
                      Text("Add Location",
                          style: TextStyle(color: Colors.white, fontSize: 18)),
                      Spacer(),
                      TextButton(
                        onPressed: () {},
                        child: Text("Cancel",
                            style: TextStyle(color: Colors.transparent)),
                      ),
                    ],
                  ),
                ),

                /// 🔹 Mapbox Map
                Container(
                  height: MediaQuery.of(context).size.height - 170,
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
                      Container(
                        height: 400,
                        width: MediaQuery.sizeOf(context).width,
                        child: map.MapWidget(
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

                            // mapboxMap!.location
                            //     .updateSettings(LocationComponentSettings(
                            //   enabled: true,
                            //   pulsingEnabled: true,
                            // ));
                          },
                        ),
                      ),

                      /// 🔹 Animated Positioned Container (Smooth Transition)
                      ValueListenableBuilder(
                          valueListenable:
                              sheetTop, // ✅ Listens to keyboard changes reactively
                          builder: (context, top, child) {
                            return AnimatedPositioned(
                              duration: Duration(
                                  milliseconds: 200), // Smooth transition
                              curve: Curves.easeInOut, // Smooth easing curve
                              top: top, // Make it sit slightly above the map
                              left: 0,
                              right: 0,
                              child: Container(
                                height: MediaQuery.of(context).size.height -
                                    350, // Fill the remaining screen
                                // height: MediaQuery.of(context).size.height,
                                decoration: BoxDecoration(
                                  color: Color(0xff001311), // Background color
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(20),
                                    topRight: Radius.circular(20),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    /// 🔹 Search Bar
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 10)
                                          .copyWith(top: 27),
                                      child: TextField(
                                        controller: searchController,
                                        onChanged: _onSearchChanged,
                                        style: TextStyle(color: Colors.white),
                                        decoration: InputDecoration(
                                          prefixIcon: Icon(Icons.search,
                                              color: Colors.white),
                                          hintText: "Search for a location",
                                          hintStyle:
                                              TextStyle(color: Colors.grey),
                                          filled: true,
                                          fillColor: Color(0xff091F1E),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                                12), // Rounded corners
                                            borderSide: BorderSide(
                                              color: Colors
                                                  .white24, // Light border color
                                              width: 1,
                                            ),
                                          ),
                                          suffixIcon: Icon(Icons.search,
                                              color: Colors.grey),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                              color: Color(
                                                  0xFF03FFE2), // Neon blue-green focus color
                                              width: 1,
                                            ),
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: BorderSide.none,
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Expanded(
                                    //   child: Container(
                                    //     height: 700,
                                    //     width: MediaQuery.sizeOf(context).width,
                                    //     color: Colors.blue,
                                    //   ),
                                    // )

                                    /// 🔹 Suggested Places List (Scrollable)
                                    Expanded(
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        controller:
                                            scrollController, // Enable smooth scrolling
                                        itemCount: suggestedPlaces.length,
                                        itemBuilder: (context, index) {
                                          final place = suggestedPlaces[index];

                                          // log('selecte place id : ${selectedSearchResultd}')

                                          return Container(
                                            margin: EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Color(0xff091F1E),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: selectedSearchResult ==
                                                        place
                                                    ? Color(0xFF03FFE2)
                                                    : Colors.transparent,
                                                width: 2,
                                              ),
                                            ),
                                            child: ListTile(
                                              // selected: isSelected,
                                              selectedColor: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                              leading: Icon(Icons.place,
                                                  color: Colors.white),
                                              title: Text(place.name,
                                                  style: TextStyle(
                                                      color: Colors.white)),
                                              subtitle: Text(
                                                  place.formattedAddress ?? "",
                                                  style: TextStyle(
                                                      color: Colors.grey)),
                                              onTap: () {
                                                setState(() {
                                                  selectedPlace = place.name;
                                                  selectedSearchResult = place;
                                                });
                                                selectLocation(
                                                    place
                                                        .geometry!.location.lat,
                                                    place
                                                        .geometry!.location.lng,
                                                    place);
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                    ),

                                    /// 🔹 Confirm Button (Fixed at Bottom)
                                  ],
                                ),
                              ),
                            );
                          }),
                      Positioned(
                          right: 20,
                          left: 20,
                          bottom: 10,
                          child: ContinueButton(
                            onPressed: () {
                              Navigator.pop(context, selectedSearchResult);
                            },
                            text: 'Confirm location',
                            color: Theme.of(context).colorScheme.primary,
                          ))
                    ],
                  ),
                ),

                /// 🔹 Search & Suggested Locations
                // Expanded(
                //   child: Container(
                //     decoration: BoxDecoration(
                //         // color: Colors.yellow,
                //         borderRadius: BorderRadius.only(
                //             topLeft: Radius.circular(20),
                //             topRight: Radius.circular(20))),
                //     child: Padding(
                //       padding: const EdgeInsets.symmetric(
                //           horizontal: 20, vertical: 27),
                //       child: Column(
                //         children: [
                //           TextField(
                //             controller: searchController,
                //             onChanged: _onSearchChanged,
                //             style: TextStyle(color: Colors.white),
                //             decoration: InputDecoration(
                //               prefixIcon:
                //                   Icon(Icons.search, color: Colors.white),
                //               hintText: "Search for a location",
                //               hintStyle: TextStyle(color: Colors.grey),
                //               filled: true,
                //               fillColor: Color(0xff091F1E),
                //               border: OutlineInputBorder(
                //                 borderRadius: BorderRadius.circular(8),
                //                 borderSide: BorderSide.none,
                //               ),
                //             ),
                //           ),

                //           /// 🔹 Suggested Places List (Scrollable)
                //           Expanded(
                //             child: ListView.builder(
                //               controller:
                //                   scrollController, // Enable scrolling inside modal
                //               itemCount: suggestedPlaces.length,
                //               // physics: NeverScrollableScrollPhysics(),
                //               shrinkWrap: true,
                //               itemBuilder: (context, index) {
                //                 final place = suggestedPlaces[index];
                //                 return ListTile(
                //                   leading:
                //                       Icon(Icons.place, color: Colors.white),
                //                   title: Text(place.name,
                //                       style: TextStyle(color: Colors.white)),
                //                   subtitle: Text(place.formattedAddress ?? "",
                //                       style: TextStyle(color: Colors.grey)),
                //                   onTap: () {
                //                     setState(() {
                //                       selectedPlace = place.name;
                //                     });
                //                     selectLocation(place.geometry!.location.lat,
                //                         place.geometry!.location.lng, place);
                //                   },
                //                 );
                //               },
                //             ),
                //           ),
                //         ],
                //       ),
                //     ),
                //   ),
                // ),
              ],
            ),
          );
        });
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
