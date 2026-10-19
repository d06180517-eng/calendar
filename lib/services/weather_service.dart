import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../data/models.dart';

/// Погода через бесплатный Open-Meteo (ключ не нужен).
class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  /// Погода по текущему месту. Если человек не ответил на запрос
  /// геолокации или сеть молчит — через 20 секунд сдаёмся.
  Future<Weather?> current() async {
    try {
      return await _current().timeout(const Duration(seconds: 20));
    } catch (_) {
      return null;
    }
  }

  Future<Weather?> _current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return await fetch(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<Weather?> fetch(double lat, double lon) async {
    try {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': lat.toStringAsFixed(3),
        'longitude': lon.toStringAsFixed(3),
        'current': 'temperature_2m,weather_code',
      });
      final r = await _client.get(uri).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      return parse(r.body);
    } catch (_) {
      return null;
    }
  }

  static Weather? parse(String body) {
    final j = jsonDecode(body);
    final c = j is Map ? j['current'] : null;
    if (c is! Map) return null;
    final t = c['temperature_2m'];
    final code = c['weather_code'];
    if (t is! num || code is! num) return null;
    return Weather(t.toDouble(), code.toInt());
  }
}

/// Значок погоды по коду WMO.
String weatherEmoji(int code) {
  if (code == 0) return '☀️';
  if (code <= 3) return '⛅';
  if (code <= 48) return '🌫️';
  if (code <= 67 || (code >= 80 && code <= 82)) return '🌧️';
  if (code <= 77 || code == 85 || code == 86) return '❄️';
  return '⛈️';
}

String formatWeather(Weather w) {
  final t = w.temperature.round();
  return '${weatherEmoji(w.code)} ${t > 0 ? '+' : ''}$t°';
}
