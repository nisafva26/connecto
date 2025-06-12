import 'package:flutter_google_maps_webservices/places.dart';

class CategoryPlaces {
  final String category;
  final List<PlacesSearchResult> results;

  CategoryPlaces({required this.category, required this.results});
}