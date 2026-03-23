import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/weather_service.dart';

final weatherServiceProvider = Provider<WeatherService>((ref) {
  return WeatherService();
});

final weatherProvider = FutureProvider<LocationWeatherData>((ref) async {
  final service = ref.read(weatherServiceProvider);
  return await service.fetchLocationAndWeather();
});
