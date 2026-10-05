import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Weather & Fuel App',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        scaffoldBackgroundColor: const Color(0xFFFFA726),
      ),
      home: const WeatherFuelScreen(),
    );
  }
}

class WeatherFuelScreen extends StatefulWidget {
  const WeatherFuelScreen({super.key});

  @override
  State<WeatherFuelScreen> createState() => _WeatherFuelScreenState();
}

class _WeatherFuelScreenState extends State<WeatherFuelScreen> {
  final TextEditingController _searchController = TextEditingController();

  String cityName = "Lucknow";

  double temperature = 31.0;
  String weatherDescription = "CLEAR SKY";
  int humidity = 55;
  double windSpeed = 2.0;
  int weatherCode = 0;

  double petrolRate = 102.72;
  double dieselRate = 88.62;

  bool isLoading = false;
  bool isFuelLoading = false;

  @override
  void initState() {
    super.initState();

    _fetchWeatherByCity(cityName);
    _loadFuelRates(cityName);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // FIREBASE FUEL RATES
  // ------------------------------------------------------------

  Future<void> _loadFuelRates(String city) async {
    final normalizedCity = city.trim().toLowerCase();

    if (normalizedCity.isEmpty) return;

    if (mounted) {
      setState(() {
        isFuelLoading = true;
      });
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('fuel_rates')
          .doc(normalizedCity)
          .get();

      if (!doc.exists) {
        debugPrint('Fuel document not found for city: $normalizedCity');
        return;
      }

      final data = doc.data();

      if (data == null) return;

      final petrol = _toDouble(data['petrol']);
      final diesel = _toDouble(data['diesel']);

      if (!mounted) return;

      setState(() {
        if (petrol != null) {
          petrolRate = petrol;
        }

        if (diesel != null) {
          dieselRate = diesel;
        }
      });
    } catch (e) {
      debugPrint('Firebase fuel rate error: $e');
    } finally {
      if (mounted) {
        setState(() {
          isFuelLoading = false;
        });
      }
    }
  }

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value);
    }

    return null;
  }

  // ------------------------------------------------------------
  // CITY WEATHER SEARCH
  // ------------------------------------------------------------

  Future<void> _fetchWeatherByCity(String queryCity) async {
    final city = queryCity.trim();

    if (city.isEmpty) {
      _showToast("Please city ka naam enter karein.");
      return;
    }

    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final geoUrl = Uri.https(
        'geocoding-api.open-meteo.com',
        '/v1/search',
        {
          'name': city,
          'count': '1',
          'language': 'en',
          'format': 'json',
        },
      );

      final geoResponse = await http
          .get(geoUrl)
          .timeout(const Duration(seconds: 10));

      if (geoResponse.statusCode != 200) {
        _showToast("City search failed. Please try again.");
        return;
      }

      final geoData = jsonDecode(geoResponse.body);
      final results = geoData['results'];

      if (results is List && results.isNotEmpty) {
        final result = results.first;

        final lat = (result['latitude'] as num?)?.toDouble();
        final lon = (result['longitude'] as num?)?.toDouble();

        if (lat == null || lon == null) {
          _showToast("Location coordinates nahi mile.");
          return;
        }

        final resultName = result['name'];

        final resolvedCity =
            resultName is String && resultName.trim().isNotEmpty
                ? resultName.trim()
                : city;

        await _getWeatherFromCoords(lat, lon, resolvedCity);
        await _loadFuelRates(resolvedCity);
      } else {
        _showToast("Shehar nahi mila!");
      }
    } catch (e) {
      debugPrint("City search error: $e");
      _showToast("City search karne mein problem aayi.");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ------------------------------------------------------------
  // GPS LOCATION
  // ------------------------------------------------------------

  Future<void> _checkPermissionsAndFetchLocation() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _showToast("GPS / Location service off hai.");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _showToast("Location permission denied.");
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _showToast(
          "Location permission permanently denied hai. Settings se enable karein.",
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      await _getWeatherFromCoords(
        position.latitude,
        position.longitude,
        "Current Location",
      );
    } catch (e) {
      debugPrint("Location error: $e");
      _showToast("Location fetch karne mein problem aayi.");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ------------------------------------------------------------
  // WEATHER
  // ------------------------------------------------------------

  Future<void> _getWeatherFromCoords(
    double lat,
    double lon,
    String name,
  ) async {
    try {
      final weatherUrl = Uri.https(
        'api.open-meteo.com',
        '/v1/forecast',
        {
          'latitude': lat.toString(),
          'longitude': lon.toString(),
          'current':
              'temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m',
          'timezone': 'auto',
        },
      );

      final response = await http
          .get(weatherUrl)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        _showToast("Weather data nahi mil saka.");
        return;
      }

      final data = jsonDecode(response.body);
      final current = data['current'];

      if (current is! Map) {
        _showToast("Weather data ka format galat hai.");
        return;
      }

      final temperatureValue =
          (current['temperature_2m'] as num?)?.toDouble();

      final humidityValue =
          (current['relative_humidity_2m'] as num?)?.toInt();

      final windValue =
          (current['wind_speed_10m'] as num?)?.toDouble();

      final codeValue =
          (current['weather_code'] as num?)?.toInt();

      if (temperatureValue == null ||
          humidityValue == null ||
          windValue == null ||
          codeValue == null) {
        _showToast("Weather information incomplete hai.");
        return;
      }

      final desc = _getWeatherDescription(codeValue);

      if (!mounted) return;

      setState(() {
        cityName = name;
        temperature = temperatureValue;
        humidity = humidityValue;
        windSpeed = windValue;
        weatherCode = codeValue;
        weatherDescription = desc;
      });
    } catch (e) {
      debugPrint("Weather data error: $e");
      _showToast("Weather data load karne mein problem aayi.");
    }
  }

  String _getWeatherDescription(int code) {
    switch (code) {
      case 0:
        return "CLEAR SKY";
      case 1:
        return "MAINLY CLEAR";
      case 2:
        return "PARTLY CLOUDY";
      case 3:
        return "OVERCAST";
      case 45:
      case 48:
        return "FOGGY";
      case 51:
      case 53:
      case 55:
        return "DRIZZLE";
      case 61:
      case 63:
      case 65:
        return "RAIN";
      case 71:
      case 73:
      case 75:
      case 77:
        return "SNOW";
      case 80:
      case 81:
      case 82:
        return "RAIN SHOWERS";
      case 95:
        return "THUNDERSTORM";
      default:
        return "UNKNOWN";
    }
  }

  IconData _getWeatherIcon(int code) {
    if (code == 0) return Icons.wb_sunny;
    if (code >= 1 && code <= 3) return Icons.cloud;
    if (code >= 45 && code <= 48) return Icons.foggy;
    if (code >= 51 && code <= 67) return Icons.grain;
    if (code >= 71 && code <= 77) return Icons.ac_unit;
    if (code >= 80 && code <= 82) return Icons.water_drop;
    if (code >= 95) return Icons.thunderstorm;
    return Icons.wb_sunny;
  }

  void _showToast(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "City search karein...",
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.2),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      onSubmitted: (value) {
                        final city = value.trim();
                        if (city.isNotEmpty) {
                          _fetchWeatherByCity(city);
                          _searchController.clear();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 5),
                  IconButton(
                    tooltip: "Search",
                    icon: const Icon(Icons.search, color: Colors.white),
                    onPressed: () {
                      final city = _searchController.text.trim();
                      if (city.isNotEmpty) {
                        _fetchWeatherByCity(city);
                        _searchController.clear();
                      }
                    },
                  ),
                  IconButton(
                    tooltip: "Current Location",
                    icon: const Icon(Icons.my_location, color: Colors.white),
                    onPressed: isLoading
                        ? null
                        : _checkPermissionsAndFetchLocation,
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Center(
                child: Column(
                  children: [
                    Text(
                      cityName.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Icon(
                      _getWeatherIcon(weatherCode),
                      size: 70,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${temperature.toStringAsFixed(1)}°C',
                      style: const TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      weatherDescription,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.water_drop,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Humidity: $humidity%',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 15),
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.air, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Wind: ${windSpeed.toStringAsFixed(1)} km/h',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                "TODAY'S LIVE FUEL RATES",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 15),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _fuelCard(
                      title: "PETROL",
                      price: petrolRate,
                      icon: Icons.local_gas_station,
                      iconColor: Colors.redAccent,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _fuelCard(
                      title: "DIESEL",
                      price: dieselRate,
                      icon: Icons.oil_barrel,
                      iconColor: Colors.blueAccent,
                    ),
                  ),
                ],
              ),
              if (isLoading || isFuelLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fuelCard({
    required String title,
    required double price,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Icon(icon, color: iconColor),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "₹${price.toStringAsFixed(2)}",
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Firebase City Rate",
            style: TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
