import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:intl/intl.dart';
import 'dart:async';
import 'services/navigation_service.dart';
import 'services/weather_service.dart';
import 'widgets/search_destination.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set Mapbox access token
  MapboxOptions.setAccessToken('pk.eyJ1IjoidG9uYnkiLCJhIjoiY21nbDVzYjdhMHhqMDJycXFxaWlkcnY2YiJ9._0ujjRjoFjGso2ZU4Zn6eQ');
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mapbox Nigeria',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF008751),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF008751),
          secondary: const Color(0xFFFFFFFF),
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
  
  // Services
  final NavigationService _navigationService = NavigationService();
  final WeatherService _weatherService = WeatherService();
  
  // Navigation state
  NavigationRoute? _currentRoute;
  geo.Position? _currentPosition;
  double _currentSpeed = 0.0;
  WeatherData? _weatherData;
  StreamSubscription<double>? _speedSubscription;
  StreamSubscription<geo.Position>? _positionSubscription;
  bool _isNavigating = false;
  String? _destinationName;
  
  // UI state
  bool _showSearch = false;

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

        // Start tracking speed
        _speedSubscription = _navigationService.getCurrentSpeed().listen((speed) {
          if (mounted) {
            setState(() {
              _currentSpeed = speed;
            });
          }
        });

        // Track position updates
        _positionSubscription = geo.Geolocator.getPositionStream(
          locationSettings: const geo.LocationSettings(
            accuracy: geo.LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((position) {
          if (mounted) {
            setState(() {
              _currentPosition = position;
            });
          }
        });
      }
    } catch (e) {
      print('Error initializing location: $e');
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

    _showSnackBar('Calculating route...');

    final route = await _navigationService.getDirections(
      startLat: _currentPosition!.latitude,
      startLng: _currentPosition!.longitude,
      endLat: destLat,
      endLng: destLng,
    );

    if (route != null) {
      setState(() {
        _currentRoute = route;
        _isNavigating = true;
        _destinationName = name;
        _showSearch = false;
      });

      // Animate to show route
      mapboxMap?.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(
              _currentPosition!.longitude,
              _currentPosition!.latitude,
            ),
          ),
          zoom: 12.0,
        ),
        MapAnimationOptions(duration: 1500, startDelay: 0),
      );

      _showSnackBar('Navigation started!');
    } else {
      _showSnackBar('Could not calculate route');
    }
  }

  void _stopNavigation() {
    setState(() {
      _currentRoute = null;
      _isNavigating = false;
      _destinationName = null;
    });
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
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
              });
            },
            tooltip: 'Search',
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _goToCurrentLocation,
            tooltip: 'My Location',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          MapWidget(
            styleUri: MapboxStyles.MAPBOX_STREETS,
            cameraOptions: CameraOptions(
              center: Point(
                coordinates: Position(8.6753, 9.0820),
              ),
              zoom: 6.0,
            ),
            onMapCreated: _onMapCreated,
          ),

          // Search bar
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

          // Speed indicator
          if (_currentSpeed > 0)
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
                    const Text(
                      'km/h',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

          // Weather widget
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
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
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

          // Navigation info panel
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
                    // Handle bar
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
                          // Destination
                          Row(
                            children: [
                              const Icon(Icons.location_on, color: Color(0xFF008751), size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Destination',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      _destinationName ?? 'Unknown',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Route info
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
                                value: _currentRoute!.distanceText,
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Next instruction
                          if (_currentRoute!.steps.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF008751).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.turn_right, color: Color(0xFF008751)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _currentRoute!.steps.first.instruction,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          
                          const SizedBox(height: 16),
                          
                          // Stop navigation button
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
                              child: const Text(
                                'Stop Navigation',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
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

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF008751), size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF008751),
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
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
          center: Point(
            coordinates: Position(
              position.longitude,
              position.latitude,
            ),
          ),
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
    super.dispose();
  }
}
