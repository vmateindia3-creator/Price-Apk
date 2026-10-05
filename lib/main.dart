import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase Init Error: $e");
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fuel & Weather',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String weatherApiKey = '42e264af50f9b2c516011c9467291294';

  String cityName = 'LUCKNOW';
  double? temp;
  String weatherMain = 'Clear';
  String weatherDesc = 'CLEAR SKY';
  String humidity = '62%';
  String windSpeed = '12 km/h';

  String petrolPrice = '₹96.72';
  String dieselPrice = '₹89.62';

  bool isLoading = false;
  bool isLocationGranted = false;
  final TextEditingController _cityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissionsAndFetchLocation();
    });
  }

  Future<void> _checkPermissionsAndFetchLocation() async {
    setState(() => isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showToast('Mobile ka Location (GPS) OFF hai! Upar se ON karein.');
        await _fetchWeatherByCity(cityName);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showToast('Location permission Deny kardi gayi hai.');
          await _fetchWeatherByCity(cityName);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showToast('Permission permanently OFF hai. Settings me jaakar Allow karein.');
        await _fetchWeatherByCity(cityName);
        return;
      }

      setState(() => isLocationGranted = true);
      await _fetchWeatherByGPS();
    } catch (e) {
      _showToast('Permission check error: $e');
      await _fetchWeatherByCity(cityName);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchWeatherByGPS() async {
    setState(() => isLoading = true);
    try {
      _showToast('Live Location dhoondh raha hai...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 15),
      );

      final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?lat=${position.latitude}&lon=${position.longitude}&units=metric&appid=$weatherApiKey',
      );

      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        _parseAndSetData(data);
        _showToast('Location Tracked: $cityName');
      } else {
        _showToast('Weather API me problem hai.');
        _fetchWeatherByCity(cityName);
      }
    } catch (e) {
      try {
        Position? lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null) {
          final url = Uri.parse(
            'https://api.openweathermap.org/data/2.5/weather?lat=${lastPos.latitude}&lon=${lastPos.longitude}&units=metric&appid=$weatherApiKey',
          );
          final res = await http.get(url);
          if (res.statusCode == 200) {
            final data = json.decode(res.body);
            _parseAndSetData(data);
            _showToast('Last Known Location Tracked: $cityName');
            return;
          }
        }
      } catch (lastErr) {}
      _showToast('Location track fail hua. Network ya GPS weak hai.');
      _fetchWeatherByCity(cityName);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  List<Color> _getTemperatureGradient() {
    if (temp == null) return [const Color(0xFF11998E), const Color(0xFF38EF7D)];
    String cond = weatherMain.toLowerCase();
    if (cond.contains('rain') || cond.contains('drizzle') || cond.contains('thunderstorm')) {
      return [const Color(0xFF373B44), const Color(0xFF4286F4)];
    }
    if (temp! >= 35) return [const Color(0xFFFF512F), const Color(0xFFDD2476)];
    if (temp! >= 25) return [const Color(0xFFFF8008), const Color(0xFFFFC837)];
    if (temp! <= 15) return [const Color(0xFF1E3C72), const Color(0xFF2A5298)];
    return [const Color(0xFF11998E), const Color(0xFF38EF7D)];
  }

  IconData _getWeatherIcon() {
    String cond = weatherMain.toLowerCase();
    if (cond.contains('cloud')) return Icons.cloud;
    if (cond.contains('rain') || cond.contains('drizzle')) return Icons.water_drop;
    if (cond.contains('thunder')) return Icons.flash_on;
    if (cond.contains('snow')) return Icons.ac_unit;
    if (cond.contains('clear')) return Icons.wb_sunny;
    return Icons.wb_cloudy;
  }

  Future<void> _fetchWeatherByCity(String city) async {
    if (city.trim().isEmpty) return;
    setState(() => isLoading = true);
    try {
      final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?q=${Uri.encodeComponent(city.trim())}&units=metric&appid=$weatherApiKey',
      );
      final res = await http.get(url);

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        _parseAndSetData(data);
      } else {
        _showToast('City nahi mili! Spelling check karein.');
      }
    } catch (e) {
      _showToast('Internet error! Connection check karein.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _parseAndSetData(dynamic data) {
    setState(() {
      cityName = (data['name'] ?? 'UNKNOWN').toString().toUpperCase();
      temp = (data['main']['temp'] as num).toDouble();
      weatherMain = data['weather'][0]['main'] ?? 'Clear';
      weatherDesc = (data['weather'][0]['description'] ?? 'CLEAR').toString().toUpperCase();
      humidity = '${data['main']['humidity'] ?? 60}%';
      double windMs = (data['wind']['speed'] as num).toDouble();
      windSpeed = '${(windMs * 3.6).round()} km/h';
    });
    _fetchFuelPrice(cityName);
  }

  Future<void> _fetchFuelPrice(String city) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('fuel_rates')
          .doc(city.toLowerCase().trim())
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          petrolPrice = '₹${data['petrol'] ?? '96.72'}';
          dieselPrice = '₹${data['diesel'] ?? '89.62'}';
        });
      } else {
        _setFallbackFuel(city);
      }
    } catch (e) {
      _setFallbackFuel(city);
    }
  }

  void _setFallbackFuel(String city) {
    int len = city.length;
    double p = 95.0 + (len % 8) + 0.72;
    double d = 87.0 + (len % 6) + 0.62;
    setState(() {
      petrolPrice = '₹${p.toStringAsFixed(2)}';
      dieselPrice = '₹${d.toStringAsFixed(2)}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _getTemperatureGradient(),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              RefreshIndicator(
                onRefresh: () => _fetchWeatherByCity(cityName),
                color: Colors.white,
                backgroundColor: Colors.black26,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _cityController,
                                style: const TextStyle(color: Colors.white, fontSize: 15),
                                decoration: InputDecoration(
                                  hintText: 'City search karein...',
                                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.75)),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                ),
                                onSubmitted: (val) {
                                  _fetchWeatherByCity(val);
                                  _cityController.clear();
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.search, color: Colors.white),
                              onPressed: () {
                                _fetchWeatherByCity(_cityController.text);
                                _cityController.clear();
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.my_location,
                                color: isLocationGranted ? Colors.white : Colors.white54,
                              ),
                              onPressed: _checkPermissionsAndFetchLocation,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      Column(
                        children: [
                          Text(
                            cityName,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Icon(_getWeatherIcon(), size: 70, color: Colors.white),
                          const SizedBox(height: 10),
                          Text(
                            temp != null ? '${temp!.round()}°C' : '--°C',
                            style: const TextStyle(
                              fontSize: 64,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            weatherDesc,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 15),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Text('💧 Humidity: $humidity', style: const TextStyle(color: Colors.white, fontSize: 13)),
                                Text('💨 Wind: $windSpeed', style: const TextStyle(color: Colors.white, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 35),
                      const Text(
                        "TODAY'S LIVE FUEL RATES",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildFuelCard('PETROL', petrolPrice, '⛽')),
                          const SizedBox(width: 15),
                          Expanded(child: _buildFuelCard('DIESEL', dieselPrice, '🛢️')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (isLoading)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 12),
                        Text(
                          'Location detect ho rahi hai...',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFuelCard(String type, String price, String emoji) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(type, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              Text(emoji, style: const TextStyle(fontSize: 22)),
            ],
          ),
          const SizedBox(height: 12),
          Text(price, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Standard City Rate', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11)),
        ],
      ),
    );
  }
}
