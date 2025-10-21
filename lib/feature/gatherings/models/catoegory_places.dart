import 'package:flutter_google_maps_webservices/places.dart';

// class CategoryPlaces {
//   final String category;
//   final List<PlacesSearchResult> results;

//   CategoryPlaces({required this.category, required this.results});
// }


class CategoryPlaces {
  final String category;
  final List<PlacesSearchResult> results;

  CategoryPlaces({
    required this.category,
    required this.results,
  });

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'results': results.map((r) => r.toJson()).toList(),
    };
  }

  factory CategoryPlaces.fromJson(Map<String, dynamic> json) {
    return CategoryPlaces(
      category: json['category'] as String,
      results: (json['results'] as List)
          .map((r) => PlacesSearchResult.fromJson(r))
          .toList(),
    );
  }
}