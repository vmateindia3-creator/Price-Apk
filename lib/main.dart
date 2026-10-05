import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const WhatsAppWeatherApp());
}

class WhatsAppWeatherApp extends StatelessWidget {
  const WhatsAppWeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WhatsApp Weather',
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'sans-serif',
      ),
      home: const WeatherHomeScreen(),
    );
  }
}

class WeatherHomeScreen extends StatefulWidget {
  const WeatherHomeScreen({super.key});

  @override
  State<WeatherHomeScreen> createState() => _WeatherHomeScreenState();
}

class _WeatherHomeScreenState extends State<WeatherHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  String cityName = "Kanpur";
  double temperature = 30.0;
  String weatherDescription = "CLEAR SKY";
  int humidity = 50;
  double windSpeed = 3.0;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchWeather(cityName);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Temperature ke hisab se WhatsApp Dark theme ke colors change karna
  Color _getBackgroundColor() {
    if (temperature < 20) {
      // Thanda mausam / Thandi raat -> Dark Blue-Grey (WhatsApp Cool Tone)
      return const Color(0xFF0F1B21);
    } else if (temperature >= 20 && temperature <= 32) {
      // Normal / Pleasant -> WhatsApp Classic Dark Green Background
      return const Color(0xFF111B21);
    } else {
      // Bahut Garmi -> Dark Charcoal / Warm Tint
      return const Color(0xFF1F1B18);
    }
  }

  Color _getAccentColor() {
    if (temperature < 20) {
      return const Color(0xFF00A884); // Cool Teal
    } else if (temperature >= 20 && temperature <= 32) {
      return const Color(0xFF00A884); // WhatsApp Signature Green
    } else {
      return const Color(0xFFFFA726); // Warm Orange for heat
    }
  }

  Future<void> _fetchWeather(String queryCity) async {
    final city = queryCity.trim();
    if (city.isEmpty) return;

    setState(() => isLoading = true);
    try {
      // 1. Geocoding API se coordinates nikalna
      final geoUrl = Uri.https(
        'geocoding-api.open-meteo.com',
        '/v1/search',
        {'name': city, 'count': '1', 'language': 'en', 'format': 'json'},
      );
      final geoRes = await http.get(geoUrl).timeout(const Duration(seconds: 10));
      
      if (geoRes.statusCode == 200) {
        final geoData = jsonDecode(geoRes.body);
        final results = geoData['results'];
        if (results is List && results.isNotEmpty) {
          final lat = results[0]['latitude'];
          final lon = results[0]['longitude'];
          final resolvedName = results[0]['name'] ?? city;

          // 2. Open-Meteo Weather API se data lena
          final weatherUrl = Uri.https(
            'api.open-meteo.com',
            '/v1/forecast',
            {
              'latitude': lat.toString(),
              'longitude': lon.toString(),
              'current': 'temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m',
              'timezone': 'auto',
            },
          );
          final weatherRes = await http.get(weatherUrl).timeout(const Duration(seconds: 10));
          
          if (weatherRes.statusCode == 200) {
            final weatherData = jsonDecode(weatherRes.body);
            final current = weatherData['current'];

            setState(() {
              cityName = resolvedName;
              temperature = (current['temperature_2m'] as num).toDouble();
              humidity = (current['relative_humidity_2m'] as num).toInt();
              windSpeed = (current['wind_speed_10m'] as num).toDouble();
              weatherDescription = _getDesc((current['weather_code'] as num).toInt());
            });
          }
        } else {
          _showSnack("Shehar nahi mila!");
        }
      }
    } catch (e) {
      _showSnack("Data fetch karne mein error aayi.");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchGPSLocation() async {
    setState(() => isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack("GPS off hai.");
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        _showSnack("Location permission permanently denied.");
        return;
      }
      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      
      // Coords se direct weather fetch karna
      final weatherUrl = Uri.https(
        'api.open-meteo.com',
        '/v1/forecast',
        {
          'latitude': pos.latitude.toString(),
          'longitude': pos.longitude.toString(),
          'current': 'temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m',
          'timezone': 'auto',
        },
      );
      final res = await http.get(weatherUrl);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final current = data['current'];
        setState(() {
          cityName = "Current GPS Location";
          temperature = (current['temperature_2m'] as num).toDouble();
          humidity = (current['relative_humidity_2m'] as num).toInt();
          windSpeed = (current['wind_speed_10m'] as num).toDouble();
          weatherDescription = _getDesc((current['weather_code'] as num).toInt());
        });
      }
    } catch (e) {
      _showSnack("GPS location fetch nahi ho saki.");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _getDesc(int code) {
    if (code == 0) return "CLEAR SKY";
    if (code <= 3) return "PARTLY CLOUDY";
    if (code <= 48) return "FOGGY / MIST";
    if (code <= 67) return "LIGHT RAIN";
    if (code <= 77) return "SNOW";
    return "THUNDERSTORM";
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _getBackgroundColor();
    final accentColor = _getAccentColor();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF202C33), // WhatsApp Header Color
        title: const Text(
          "WhatsApp Weather",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location, color: Colors.white70),
            onPressed: isLoading ? null : _fetchGPSLocation,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // WhatsApp Style Search Bar Container
            Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFF111B21),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF202C33),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: "Search city...",
                          hintStyle: TextStyle(color: Colors.white54),
                          prefixIcon: Icon(Icons.search, color: Colors.white54),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onSubmitted: (val) {
                          if (val.trim().isNotEmpty) {
                            _fetchWeather(val.trim());
                            _searchController.clear();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // City Header Card (WhatsApp Message Bubble Style)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF202C33),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.location_pin, color: Colors.white70, size: 20),
                              const SizedBox(width: 6),
                              Text(
                                cityName.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            '${temperature.toStringAsFixed(1)}°C',
                            style: TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            weatherDescription,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white60,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Details Info Row (WhatsApp Chat Details Style)
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF202C33),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.water_drop, color: Colors.blueAccent),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Humidity", style: TextStyle(color: Colors.white54, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Text("$humidity%", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF202C33),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.air, color: Colors.tealAccent),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Wind Speed", style: TextStyle(color: Colors.white54, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Text("$windSpeed km/h", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 30),
                        child: CircularProgressIndicator(color: Color(0xFF00A884)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
