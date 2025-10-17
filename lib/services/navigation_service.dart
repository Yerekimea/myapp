import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart' as geo;

class NavigationService {
  static const String _mapboxToken = 'pk.eyJ1IjoidG9uYnkiLCJhIjoiY21nbDVzYjdhMHhqMDJycXFxaWlkcnY2YiJ9._0ujjRjoFjGso2ZU4Zn6eQ';
  
  // Get directions from Mapbox Directions API
  Future<NavigationRoute?> getDirections({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    try {
      final url = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/driving-traffic/'
        '$startLng,$startLat;$endLng,$endLat'
        '?geometries=geojson'
        '&overview=full'
        '&steps=true'
        '&access_token=$_mapboxToken'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          return NavigationRoute.fromJson(data['routes'][0]);
        }
      }
      return null;
    } catch (e) {
      print('Error getting directions: $e');
      return null;
    }
  }

  // Get traffic data
  Future<TrafficInfo> getTrafficInfo({
    required double lat,
    required double lng,
  }) async {
    // Simulated traffic data - in production, use real traffic API
    return TrafficInfo(
      congestionLevel: 'moderate',
      averageSpeed: 45.0,
      incidents: [],
    );
  }

  // Calculate current speed
  Stream<double> getCurrentSpeed() async* {
    await for (final position in geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: 10,
      ),
    )) {
      // Speed is in m/s, convert to km/h
      yield position.speed * 3.6;
    }
  }
}

class NavigationRoute {
  final double distance; // in meters
  final double duration; // in seconds
  final List<RouteStep> steps;
  final List<List<double>> coordinates;
  final String? trafficCongestion;

  NavigationRoute({
    required this.distance,
    required this.duration,
    required this.steps,
    required this.coordinates,
    this.trafficCongestion,
  });

  factory NavigationRoute.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry']['coordinates'] as List;
    final coordinates = geometry.map((coord) => 
      [coord[0] as double, coord[1] as double]
    ).toList();

    final legs = json['legs'] as List;
    final steps = <RouteStep>[];
    
    for (var leg in legs) {
      final legSteps = leg['steps'] as List;
      for (var step in legSteps) {
        steps.add(RouteStep.fromJson(step));
      }
    }

    return NavigationRoute(
      distance: (json['distance'] as num).toDouble(),
      duration: (json['duration'] as num).toDouble(),
      steps: steps,
      coordinates: coordinates,
      trafficCongestion: json['congestion'],
    );
  }

  String get distanceText {
    if (distance < 1000) {
      return '${distance.toInt()} m';
    }
    return '${(distance / 1000).toStringAsFixed(1)} km';
  }

  String get durationText {
    final minutes = (duration / 60).round();
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '$hours hr $remainingMinutes min';
  }

  DateTime get estimatedArrival {
    return DateTime.now().add(Duration(seconds: duration.toInt()));
  }
}

class RouteStep {
  final String instruction;
  final double distance;
  final double duration;
  final String? maneuver;

  RouteStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    this.maneuver,
  });

  factory RouteStep.fromJson(Map<String, dynamic> json) {
    return RouteStep(
      instruction: json['maneuver']['instruction'] ?? '',
      distance: (json['distance'] as num).toDouble(),
      duration: (json['duration'] as num).toDouble(),
      maneuver: json['maneuver']['type'],
    );
  }
}

class TrafficInfo {
  final String congestionLevel; // low, moderate, heavy, severe
  final double averageSpeed;
  final List<TrafficIncident> incidents;

  TrafficInfo({
    required this.congestionLevel,
    required this.averageSpeed,
    required this.incidents,
  });
}

class TrafficIncident {
  final String type;
  final String description;
  final double lat;
  final double lng;

  TrafficIncident({
    required this.type,
    required this.description,
    required this.lat,
    required this.lng,
  });
}
