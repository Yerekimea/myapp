import 'dart:convert';
import 'package:http/http.dart' as http;

class PlacesService {
  static const String _mapboxToken = 'pk.eyJ1IjoidG9uYnkiLCJhIjoiY21nbDVzYjdhMHhqMDJycXFxaWlkcnY2YiJ9._0ujjRjoFjGso2ZU4Zn6eQ';
  
  // Nigeria coordinates bounds
  static const double _nigeriaMinLat = 4.0;
  static const double _nigeriaMaxLat = 14.0;
  static const double _nigeriaMinLng = 2.5;
  static const double _nigeriaMaxLng = 14.5;
  
  // Major city centers (for proximity boost)
  static const Map<String, List<double>> _majorCities = {
    'Lagos': [3.3792, 6.5244],      // [lng, lat]
    'Abuja': [7.4969, 9.0765],
    'Port Harcourt': [7.0498, 4.7661],
  };

  /// Search for places in Nigeria using Mapbox Places API
  /// Biases results toward major Nigerian cities
  Future<List<PlaceResult>> searchPlaces({
    required String query,
    double? userLat,
    double? userLng,
    int limit = 8,
  }) async {
    try {
      // Determine bias center (user location or major city center)
      double biasLat = _majorCities['Lagos']![1];
      double biasLng = _majorCities['Lagos']![0];
      
      if (userLat != null && userLng != null) {
        biasLat = userLat;
        biasLng = userLng;
      }

      // Build Mapbox Places API URL with Nigerian focus
      final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$query.json'
        '?country=ng'  // Restrict to Nigeria
        '&limit=$limit'
        '&proximity=$biasLng,$biasLat'  // Bias toward user or Lagos
        '&bbox=$_nigeriaMinLng,$_nigeriaMinLat,$_nigeriaMaxLng,$_nigeriaMaxLat'  // Bounding box for Nigeria
        '&types=place,poi,address'
        '&access_token=$_mapboxToken'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['features'] != null) {
          final results = <PlaceResult>[];
          for (var feature in data['features']) {
            results.add(PlaceResult.fromJson(feature));
          }
          return results;
        }
      }
      return [];
    } catch (e) {
      print('Error searching places: $e');
      return [];
    }
  }

  /// Get Nigerian place suggestions with common locations
  Future<List<PlaceResult>> getCommonPlaces({
    double? userLat,
    double? userLng,
  }) async {
    final results = <PlaceResult>[];
    
    // Add major cities
    results.add(PlaceResult(
      name: 'Lagos',
      description: 'Major city in Nigeria',
      latitude: _majorCities['Lagos']![1],
      longitude: _majorCities['Lagos']![0],
      placeType: 'place',
    ));
    
    results.add(PlaceResult(
      name: 'Abuja',
      description: 'Capital of Nigeria',
      latitude: _majorCities['Abuja']![1],
      longitude: _majorCities['Abuja']![0],
      placeType: 'place',
    ));
    
    results.add(PlaceResult(
      name: 'Port Harcourt',
      description: 'Major city in Nigeria',
      latitude: _majorCities['Port Harcourt']![1],
      longitude: _majorCities['Port Harcourt']![0],
      placeType: 'place',
    ));

    // Add popular landmarks and POI categories
    final commonSearches = [
      'Shopping Mall',
      'Hospital',
      'Bank',
      'Restaurant',
      'Hotel',
      'Gas Station',
      'Supermarket',
    ];

    for (final search in commonSearches) {
      try {
        final places = await searchPlaces(
          query: search,
          userLat: userLat,
          userLng: userLng,
          limit: 2,
        );
        results.addAll(places);
      } catch (e) {
        continue;
      }
    }

    return results;
  }
}

class PlaceResult {
  final String name;
  final String? description;
  final double latitude;
  final double longitude;
  final String? placeType;

  PlaceResult({
    required this.name,
    this.description,
    required this.latitude,
    required this.longitude,
    this.placeType,
  });

  factory PlaceResult.fromJson(Map<String, dynamic> json) {
    final coords = json['geometry']['coordinates'] as List;
    final properties = json['properties'] as Map<String, dynamic>?;
    
    return PlaceResult(
      name: json['text'] ?? json['place_name'] ?? 'Unknown',
      description: json['place_name'] ?? json['context']?[0]?['text'],
      longitude: coords[0].toDouble(),
      latitude: coords[1].toDouble(),
      placeType: json['type'] ?? 'poi',
    );
  }

  @override
  String toString() => '$name ${description != null ? "($description)" : ""}';
}
