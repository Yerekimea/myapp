import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math' as math;
import 'services/navigation_service.dart';
import 'services/weather_service.dart';
import 'widgets/search_destination.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  MapboxOptions.setAccessToken('pk.eyJ1IjoidG9uYnkiLCJhIjoiY21nbDVzYjdhMHhqMDJycXFxaWlkcnY2YiJ9._0ujjRjoFjGso2ZU4Zn6eQ');
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Naija Navigator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF008751),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF008751),
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF008751),
          foregroundColor: Colors.white,
          elevation: 2,
        ),
      ),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapboxMap? mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  PolylineAnnotationManager? _polylineAnnotationManager;
  
  final NavigationService _navigationService = NavigationService();
  final WeatherService _weatherService = WeatherService();
  
  NavigationRoute? _currentRoute;
  List<NavigationRoute>? _alternativeRoutes;
  NavigationUpdate? _navigationUpdate;
  geo.Position? _currentPosition;
  double _currentSpeed = 0.0;
  WeatherData? _weatherData;
  StreamSubscription<double>? _speedSubscription;
  StreamSubscription<geo.Position>? _positionSubscription;
  bool _isNavigating = false;
  String? _destinationName;
  Timer? _navigationUpdateTimer;
  
  bool _showSearch = false;
  bool _showAlternatives = false;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _loadWeather();
  }

  Future<void> _initializeLocation() async {
    try {
      geo.LocationPermission permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }

      if (permission != geo.LocationPermission.denied &&
          permission != geo.LocationPermission.deniedForever) {
        final position = await geo.Geolocator.getCurrentPosition();
        setState(() {
          _currentPosition = position;
        });

        _speedSubscription = _navigationService.getCurrentSpeed().listen((speed) {
          if (mounted) {
            setState(() {
              _currentSpeed = speed;
            });
          }
        });

        _positionSubscription = geo.Geolocator.getPositionStream(
          locationSettings: const geo.LocationSettings(
            accuracy: geo.LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((position) {
          if (mounted) {
            setState(() {
              _currentPosition = position;
            });
            _updateVehicleMarker(position);
            
            if (_isNavigating && _currentRoute != null) {
              _updateNavigationProgress(position);
            }
          }
        });
      }
    } catch (e) {
      print('Error initializing location: $e');
    }
  }

  Future<void> _updateVehicleMarker(geo.Position position) async {
    if (_pointAnnotationManager != null && mapboxMap != null) {
      await _pointAnnotationManager!.deleteAll();
      
      final options = PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(position.longitude, position.latitude),
        ),
        iconImage: "car",
        iconSize: 1.5,
        iconRotate: position.heading,
      );
      
      await _pointAnnotationManager!.create(options);
    }
  }

  void _updateNavigationProgress(geo.Position position) {
    if (_currentRoute != null) {
      final update = _navigationService.updateNavigation(
        route: _currentRoute!,
        currentPosition: position,
      );
      
      if (update != null) {
        setState(() {
          _navigationUpdate = update;
        });
      }
    }
  }

  Future<void> _loadWeather() async {
    if (_currentPosition != null) {
      final weather = await _weatherService.getCurrentWeather(
        lat: _currentPosition!.latitude,
        lng: _currentPosition!.longitude,
      );
      if (mounted) {
        setState(() {
          _weatherData = weather;
        });
      }
    }
  }

  Future<void> _startNavigation(double destLat, double destLng, String name) async {
    if (_currentPosition == null) {
      _showSnackBar('Getting your location...');
      return;
    }

    _showSnackBar('Calculating routes...');

    final routes = await _navigationService.getDirectionsWithAlternatives(
      startLat: _currentPosition!.latitude,
      startLng: _currentPosition!.longitude,
      endLat: destLat,
      endLng: destLng,
    );

    if (routes.isNotEmpty) {
      setState(() {
        _currentRoute = routes.first;
        _alternativeRoutes = routes.length > 1 ? routes.sublist(1) : null;
        _isNavigating = true;
        _destinationName = name;
        _showSearch = false;
        _showAlternatives = routes.length > 1;
      });

      await _drawRouteOnMap(_currentRoute!);
      _fitMapToRoute(_currentRoute!);
      
      // Speak first instruction
      if (_currentRoute!.steps.isNotEmpty) {
        _navigationService.speak("Navigation started. ${_currentRoute!.steps.first.instruction}");
      }

      _showSnackBar('Navigation started! ${routes.length > 1 ? "${routes.length - 1} alternative route(s) available" : ""}');
    } else {
      _showSnackBar('Could not calculate route');
    }
  }

  Future<void> _drawRouteOnMap(NavigationRoute route, {bool isAlternative = false}) async {
    if (_polylineAnnotationManager != null && route.coordinates.isNotEmpty) {
      final points = route.coordinates.map((coord) {
        return Position(coord[0], coord[1]);
      }).toList();

      final options = PolylineAnnotationOptions(
        geometry: LineString(coordinates: points),
        lineColor: isAlternative ? Colors.grey.value : const Color(0xFF008751).value,
        lineWidth: isAlternative ? 4.0 : 6.0,
        lineOpacity: isAlternative ? 0.5 : 0.9,
      );

      await _polylineAnnotationManager!.create(options);
    }
  }

  void _fitMapToRoute(NavigationRoute route) {
    if (mapboxMap != null && route.coordinates.isNotEmpty) {
      final coords = route.coordinates;
      final firstCoord = coords.first;
      final lastCoord = coords.last;
      
      final centerLat = (firstCoord[1] + lastCoord[1]) / 2;
      final centerLng = (firstCoord[0] + lastCoord[0]) / 2;
      
      mapboxMap?.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(centerLng, centerLat)),
          zoom: 12.0,
        ),
        MapAnimationOptions(duration: 1500, startDelay: 0),
      );
    }
  }

  void _selectAlternativeRoute(NavigationRoute route) async {
    setState(() {
      _currentRoute = route;
      _showAlternatives = false;
    });
    
    if (_polylineAnnotationManager != null) {
      await _polylineAnnotationManager!.deleteAll();
    }
    
    await _drawRouteOnMap(route);
    _fitMapToRoute(route);
    _showSnackBar('Route changed');
  }

  void _stopNavigation() {
    setState(() {
      _currentRoute = null;
      _alternativeRoutes = null;
      _navigationUpdate = null;
      _isNavigating = false;
      _destinationName = null;
      _showAlternatives = false;
    });
    
    _navigationService.resetNavigation();
    _navigationUpdateTimer?.cancel();
    
    if (_polylineAnnotationManager != null) {
      _polylineAnnotationManager!.deleteAll();
    }
    
    _showSnackBar('Navigation stopped');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.navigation, size: 24),
            SizedBox(width: 8),
            Text('Naija Navigator'),
          ],
        ),
        actions: [
          if (_showAlternatives && _alternativeRoutes != null)
            IconButton(
              icon: const Icon(Icons.alt_route),
              onPressed: () {
                _showAlternativeRoutesDialog();
              },
              tooltip: 'Alternative Routes',
            ),
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _goToCurrentLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          MapWidget(
            styleUri: MapboxStyles.SATELLITE_STREETS, // Detailed satellite + streets
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(8.6753, 9.0820)),
              zoom: 6.0,
            ),
            onMapCreated: _onMapCreated,
          ),

          if (_showSearch)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: SearchDestination(
                onDestinationSelected: (lat, lng, name) {
                  _startNavigation(lat, lng, name);
                },
              ),
            ),

          if (_currentSpeed > 0 && _isNavigating)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.speed, color: Color(0xFF008751)),
                    const SizedBox(height: 4),
                    Text(
                      '${_currentSpeed.toInt()}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF008751),
                      ),
                    ),
                    const Text('km/h', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ),

          if (_weatherData != null && !_isNavigating)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wb_sunny, color: Colors.orange, size: 32),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _weatherData!.temperatureText,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _weatherData!.condition,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Step-by-step instruction banner
          if (_isNavigating && _navigationUpdate != null)
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF008751),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.turn_right, color: Colors.white, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _navigationUpdate!.distanceToManeuverText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _navigationUpdate!.currentStep.instruction,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_isNavigating && _currentRoute != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on, color: Color(0xFF008751), size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Destination', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    Text(
                                      _destinationName ?? 'Unknown',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 20),
                          
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildInfoCard(
                                icon: Icons.access_time,
                                label: 'ETA',
                                value: DateFormat('HH:mm').format(_currentRoute!.estimatedArrival),
                              ),
                              _buildInfoCard(
                                icon: Icons.timer,
                                label: 'Duration',
                                value: _currentRoute!.durationText,
                              ),
                              _buildInfoCard(
                                icon: Icons.straighten,
                                label: 'Distance',
                                value: _navigationUpdate != null 
                                    ? '${(_navigationUpdate!.remainingDistance / 1000).toStringAsFixed(1)} km'
                                    : _currentRoute!.distanceText,
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _stopNavigation,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Stop Navigation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: !_isNavigating
          ? FloatingActionButton.extended(
              onPressed: () {
                setState(() {
                  _showSearch = true;
                });
              },
              backgroundColor: const Color(0xFF008751),
              icon: const Icon(Icons.navigation),
              label: const Text('Navigate'),
            )
          : null,
    );
  }

  void _showAlternativeRoutesDialog() {
    if (_alternativeRoutes == null) return;
    
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Alternative Routes',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...(_alternativeRoutes!.asMap().entries.map((entry) {
                final index = entry.key;
                final route = entry.value;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF008751),
                    child: Text('${index + 2}'),
                  ),
                  title: Text('Route ${index + 2}'),
                  subtitle: Text('${route.durationText} • ${route.distanceText}'),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () {
                    Navigator.pop(context);
                    _selectAlternativeRoute(route);
                  },
                );
              }).toList()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard({required IconData icon, required String label, required String value}) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF008751), size: 24),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF008751))),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;
    
    _pointAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager();
    _polylineAnnotationManager = await mapboxMap.annotations.createPolylineAnnotationManager();
    
    if (_currentPosition != null) {
      _updateVehicleMarker(_currentPosition!);
    }
  }

  Future<void> _goToCurrentLocation() async {
    try {
      geo.LocationPermission permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) {
          _showSnackBar('Location permission denied');
          return;
        }
      }

      if (permission == geo.LocationPermission.deniedForever) {
        _showSnackBar('Location permissions are permanently denied');
        return;
      }

      final position = await geo.Geolocator.getCurrentPosition();
      
      mapboxMap?.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(position.longitude, position.latitude)),
          zoom: 14.0,
        ),
        MapAnimationOptions(duration: 2000, startDelay: 0),
      );

      _showSnackBar('Showing your current location');
    } catch (e) {
      _showSnackBar('Error getting location: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _speedSubscription?.cancel();
    _positionSubscription?.cancel();
    _navigationUpdateTimer?.cancel();
    _navigationService.stopSpeaking();
    super.dispose();
  }
}
