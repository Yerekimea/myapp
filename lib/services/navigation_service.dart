import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:flutter_tts/flutter_tts.dart';

class NavigationService {
  static const String _mapboxToken = 'pk.eyJ1IjoidG9uYnkiLCJhIjoiY21nbDVzYjdhMHhqMDJycXFxaWlkcnY2YiJ9._0ujjRjoFjGso2ZU4Zn6eQ';
  
  final FlutterTts _tts = FlutterTts();
  int _currentStepIndex = 0;
  geo.Position? _lastPosition;
  
  NavigationService() {
    _initializeTts();
  }
  
  Future<void> _initializeTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }
  
  Future<void> speak(String text) async {
    await _tts.speak(text);
  }
  
  Future<void> stopSpeaking() async {
    await _tts.stop();
  }
  
  // Get directions with alternatives from Mapbox Directions API
  Future<List<NavigationRoute>> getDirectionsWithAlternatives({
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
        '&alternatives=true'
        '&voice_instructions=true'
        '&banner_instructions=true'
        '&access_token=$_mapboxToken'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final routes = <NavigationRoute>[];
          for (var routeData in data['routes']) {
            routes.add(NavigationRoute.fromJson(routeData));
          }
          return routes;
        }
      }
      return [];
    } catch (e) {
      print('Error getting directions: $e');
      return [];
    }
  }
  
  // Get single route (backward compatibility)
  Future<NavigationRoute?> getDirections({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    final routes = await getDirectionsWithAlternatives(
      startLat: startLat,
      startLng: startLng,
      endLat: endLat,
      endLng: endLng,
    );
    return routes.isNotEmpty ? routes.first : null;
  }
  
  // Update navigation based on current position
  NavigationUpdate? updateNavigation({
    required NavigationRoute route,
    required geo.Position currentPosition,
  }) {
    _lastPosition = currentPosition;
    
    // Find current step based on proximity
    for (int i = _currentStepIndex; i < route.steps.length; i++) {
      final step = route.steps[i];
      // Simple distance check - in production, use more sophisticated logic
      if (i < route.steps.length - 1) {
        final nextStep = route.steps[i + 1];
        // If we're close to the next step, advance
        if (_isCloseToPoint(currentPosition, nextStep.startLat, nextStep.startLng)) {
          _currentStepIndex = i + 1;
          // Speak the instruction
          speak(route.steps[_currentStepIndex].instruction);
          break;
        }
      }
    }
    
    final currentStep = route.steps[_currentStepIndex];
    final distanceToStep = _calculateDistance(
      currentPosition.latitude,
      currentPosition.longitude,
      currentStep.endLat,
      currentStep.endLng,
    );
    
    return NavigationUpdate(
      currentStepIndex: _currentStepIndex,
      currentStep: currentStep,
      distanceToNextManeuver: distanceToStep,
      remainingDistance: _calculateRemainingDistance(route, _currentStepIndex, currentPosition),
    );
  }
  
  bool _isCloseToPoint(geo.Position position, double lat, double lng, {double thresholdMeters = 30}) {
    final distance = _calculateDistance(position.latitude, position.longitude, lat, lng);
    return distance < thresholdMeters;
  }
  
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return geo.Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }
  
  double _calculateRemainingDistance(NavigationRoute route, int currentStepIndex, geo.Position position) {
    double remaining = 0;
    
    // Distance to end of current step
    if (currentStepIndex < route.steps.length) {
      final currentStep = route.steps[currentStepIndex];
      remaining += _calculateDistance(
        position.latitude,
        position.longitude,
        currentStep.endLat,
        currentStep.endLng,
      );
      
      // Add remaining steps
      for (int i = currentStepIndex + 1; i < route.steps.length; i++) {
        remaining += route.steps[i].distance;
      }
    }
    
    return remaining;
  }
  
  void resetNavigation() {
    _currentStepIndex = 0;
    _lastPosition = null;
    stopSpeaking();
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
  final double startLat;
  final double startLng;
  final double endLat;
  final double endLng;

  RouteStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    this.maneuver,
    required this.startLat,
    required this.startLng,
    required this.endLat,
    required this.endLng,
  });

  factory RouteStep.fromJson(Map<String, dynamic> json) {
    final maneuverLocation = json['maneuver']['location'] as List;
    final geometry = json['geometry'];
    
    // Get end coordinates from geometry
    double endLat = maneuverLocation[1];
    double endLng = maneuverLocation[0];
    
    if (geometry != null && geometry['coordinates'] != null) {
      final coords = geometry['coordinates'] as List;
      if (coords.isNotEmpty) {
        final lastCoord = coords.last;
        endLat = lastCoord[1];
        endLng = lastCoord[0];
      }
    }
    
    return RouteStep(
      instruction: json['maneuver']['instruction'] ?? '',
      distance: (json['distance'] as num).toDouble(),
      duration: (json['duration'] as num).toDouble(),
      maneuver: json['maneuver']['type'],
      startLat: maneuverLocation[1],
      startLng: maneuverLocation[0],
      endLat: endLat,
      endLng: endLng,
    );
  }
  
  String get distanceText {
    if (distance < 1000) {
      return '${distance.toInt()} m';
    }
    return '${(distance / 1000).toStringAsFixed(1)} km';
  }
}

class NavigationUpdate {
  final int currentStepIndex;
  final RouteStep currentStep;
  final double distanceToNextManeuver;
  final double remainingDistance;

  NavigationUpdate({
    required this.currentStepIndex,
    required this.currentStep,
    required this.distanceToNextManeuver,
    required this.remainingDistance,
  });
  
  String get distanceToManeuverText {
    if (distanceToNextManeuver < 1000) {
      return '${distanceToNextManeuver.toInt()} m';
    }
    return '${(distanceToNextManeuver / 1000).toStringAsFixed(1)} km';
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
