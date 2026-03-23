import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationWeatherData {
  final String city;
  final String countryCode;
  final int weatherCode;
  final double temperature;
  final int utcOffsetSeconds;

  LocationWeatherData({
    required this.city,
    required this.countryCode,
    required this.weatherCode,
    required this.temperature,
    required this.utcOffsetSeconds,
  });
}

class WeatherService {
  Future<LocationWeatherData> fetchLocationAndWeather() async {
    // 1. Get Location by IP
    final ipResponse = await http.get(
      Uri.parse('http://ip-api.com/json?fields=status,country,countryCode,city,lat,lon,timezone,offset'),
    );

    if (ipResponse.statusCode != 200) {
      throw Exception('Failed to load location data');
    }

    final ipData = jsonDecode(ipResponse.body);
    if (ipData['status'] != 'success') {
      throw Exception('Failed to get location from IP');
    }

    final String city = ipData['city'] ?? 'Unknown';
    final String countryCode = ipData['countryCode'] ?? 'US';
    final double lat = (ipData['lat'] as num).toDouble();
    final double lon = (ipData['lon'] as num).toDouble();
    final int offset = (ipData['offset'] as num).toInt();

    // 2. Get Weather from Open-Meteo
    final weatherResponse = await http.get(
      Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true'),
    );

    if (weatherResponse.statusCode != 200) {
      throw Exception('Failed to load weather data');
    }

    final weatherData = jsonDecode(weatherResponse.body);
    final current = weatherData['current_weather'];
    if (current == null) {
      throw Exception('Current weather data is missing');
    }

    final double temperature = (current['temperature'] as num).toDouble();
    final int weatherCode = (current['weathercode'] as num).toInt();

    return LocationWeatherData(
      city: city,
      countryCode: countryCode,
      weatherCode: weatherCode,
      temperature: temperature,
      utcOffsetSeconds: offset,
    );
  }
}
