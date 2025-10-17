import 'package:weather/weather.dart';

class WeatherService {
  // OpenWeatherMap API key - You'll need to get your own from https://openweathermap.org/api
  static const String _apiKey = ''; // Add your API key here
  late WeatherFactory _weatherFactory;

  WeatherService() {
    if (_apiKey.isNotEmpty) {
      _weatherFactory = WeatherFactory(_apiKey);
    }
  }

  Future<WeatherData?> getCurrentWeather({
    required double lat,
    required double lng,
  }) async {
    try {
      if (_apiKey.isEmpty) {
        // Return mock data if no API key
        return WeatherData(
          temperature: 28.0,
          condition: 'Partly Cloudy',
          humidity: 65,
          windSpeed: 12.0,
          icon: '02d',
        );
      }

      final weather = await _weatherFactory.currentWeatherByLocation(lat, lng);
      
      return WeatherData(
        temperature: weather.temperature?.celsius ?? 0,
        condition: weather.weatherDescription ?? 'Unknown',
        humidity: weather.humidity?.toInt() ?? 0,
        windSpeed: weather.windSpeed ?? 0,
        icon: weather.weatherIcon ?? '',
      );
    } catch (e) {
      print('Error getting weather: $e');
      // Return mock data on error
      return WeatherData(
        temperature: 28.0,
        condition: 'Partly Cloudy',
        humidity: 65,
        windSpeed: 12.0,
        icon: '02d',
      );
    }
  }
}

class WeatherData {
  final double temperature;
  final String condition;
  final int humidity;
  final double windSpeed;
  final String icon;

  WeatherData({
    required this.temperature,
    required this.condition,
    required this.humidity,
    required this.windSpeed,
    required this.icon,
  });

  String get temperatureText => '${temperature.toInt()}°C';
  String get windSpeedText => '${windSpeed.toInt()} km/h';
  String get humidityText => '$humidity%';
}
