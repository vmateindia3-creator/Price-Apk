import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package0:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase Init Warning: $e");
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fuel & Weather Live',
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

  String currentCity = 'Lucknow';
  double? currentTemp;
  String weatherMain = 'Clear';
  String weatherDesc = 'Loading mausam...';
  String petrolPrice = 'Fetching...';
  String dieselPrice = 'Fetching...';
  bool isLoading = false;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await fetchByCityName(currentCity);
  }

  void _showNotification(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // Weather Dynamic Gradient Background Logic
  List<Color> _getDynamicBackgroundColors() {
    if (currentTemp == null) {
      return [const Color(0xFF1E3C72), const Color(0xFF2A5298)]; // Default Blue
    }

    String cond = weatherMain.toLowerCase();

    if (cond.contains('rain') || cond.contains('drizzle') || cond.contains('thunderstorm')) {
      return [const Color(0xFF373B44), const Color(0xFF4286F4)]; // Rainy Storm Dark
    }

    if (currentTemp! >= 35) {
      return [const Color(0xFFFF512F), const Color(0xFFDD2476)]; // Very Hot / Heatwave
    } else if (currentTemp! >= 25) {
      return [const Color(0xFFFF8008), const Color(0xFFFFC837)]; // Warm Sunny
    } else if (currentTemp! <= 15) {
      return [const Color(0xFF83A4D4), const Color(0xFFB6FBFF)]; // Cold Crisp
    } else {
      return [const Color(0xFF3A7BD5), const Color(0xFF3A6073)]; // Pleasant Balanced
    }
  }

  IconData _getWeatherIcon() {
    String cond = weatherMain.toLowerCase();
    if (cond.contains('cloud')) return Icons.cloud;
    if (cond.contains('rain')) return Icons.thunderstorm;
    if (cond.contains('clear')) return Icons.wb_sunny;
    if (cond.contains('snow')) return Icons.ac_unit;
    return Icons.wb_cloudy;
  }

  // Location / GPS Fetch Handler
  Future<void> fetchByGPS() async {
    setState(() => isLoading = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showNotification('GPS Services OFF hain. Kripya Location ON karein.');
        setState(() => isLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showNotification('Location Permission Deny ki gayi hai.');
          setState(() => isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showNotification('Settings se Location Permission Allow karein.');
        setState(() => isLoading = false);
        return;
      }

      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final url = Uri.parse(
        '[https://api.openweathermap.org/data/2.5/weather?lat=$](https://api.openweathermap.org/data/2.5/weather?lat=$){pos.latitude}&lon=${pos.longitude}&units=metric&appid=$weatherApiKey',
      );

      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        _applyWeatherData(data);
        _showNotification('GPS Location Detected: $currentCity');
      } else {
        _showNotification('GPS Location Weather Update Failed.');
      }
    } catch (e) {
      _showNotification('Location Detect karne me error aaya.');
    } finally {
      setState(() => isLoading = false);
    }
  }

  // City Search Handler
  Future<void> fetchByCityName(String cityName) async {
    if (cityName.trim().isEmpty) return;
    setState(() => isLoading = true);

    try {
      final url = Uri.parse(
        '[https://api.openweathermap.org/data/2.5/weather?q=$](https://api.openweathermap.org/data/2.5/weather?q=$){cityName.trim()}&units=metric&appid=$weatherApiKey',
      );

      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        _applyWeatherData(data);
      } else {
        _showNotification('City nahi mili! Kripya sahi naam enter karein.');
      }
    } catch (e) {
      _showNotification('Network Issue! Connection check karein.');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _applyWeatherData(dynamic data) {
    setState(() {
      currentCity = data['name'] ?? 'Unknown';
      currentTemp = (data['main']['temp'] as num).toDouble();
      weatherMain = data['weather'][0]['main'] ?? 'Clear';
      weatherDesc = data['weather'][0]['description'] ?? 'Sunny';
    });
    _fetchFuelPriceFromFirestore(currentCity);
  }

  Future<void> _fetchFuelPriceFromFirestore(String city) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('fuel_rates')
          .doc(city.toLowerCase().trim())
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          petrolPrice = '₹${data['petrol'] ?? 'N/A'}';
          dieselPrice = '₹${data['diesel'] ?? 'N/A'}';
        });
      } else {
        setState(() {
          petrolPrice = '₹96.72'; // Fallback estimated rates if doc not created
          dieselPrice = '₹89.62';
        });
      }
    } catch (e) {
      setState(() {
        petrolPrice = '₹96.72';
        dieselPrice = '₹89.62';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColors = _getDynamicBackgroundColors();

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: bgColors,
          ),
        ),
        child: SafeArea(
          child: isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : RefreshIndicator(
                  color: Colors.indigo,
                  onRefresh: () => fetchByCityName(currentCity),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Search & GPS
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: 'City Search karein...',
                                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.search, color: Colors.white),
                                      onPressed: () {
                                        fetchByCityName(_searchController.text);
                                        _searchController.clear();
                                      },
                                    ),
                                  ),
                                  onSubmitted: (val) {
                                    fetchByCityName(val);
                                    _searchController.clear();
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            InkWell(
                              onTap: fetchByGPS,
                              borderRadius: BorderRadius.circular(15),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: const Icon(Icons.my_location, color: Colors.white, size: 26),
                              ),
                            )
                          ],
                        ),

                        const SizedBox(height: 30),

                        // Location Title & Mausam Main Display
                        Center(
                          child: Column(
                            children: [
                              Text(
                                currentCity.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.extrabold,
                                  color: Colors.white,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Icon(_getWeatherIcon(), size: 80, color: Colors.white),
                              const SizedBox(height: 10),
                              Text(
                                currentTemp != null ? '${currentTemp!.toStringAsFixed(1)}°C' : '--°C',
                                style: const TextStyle(
                                  fontSize: 64,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                weatherDesc.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.9),
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Fuel Rates Container
                        const Text(
                          'TODAY\'S FUEL RATES',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 15),

                        Row(
                          children: [
                            // Petrol Rate Glass Card
                            Expanded(
                              child: _buildFuelCard(
                                title: 'PETROL',
                                price: petrolPrice,
                                icon: Icons.local_gas_station,
                                color: Colors.orangeAccent,
                              ),
                            ),
                            const SizedBox(width: 15),
                            // Diesel Rate Glass Card
                            Expanded(
                              child: _buildFuelCard(
                                title: 'DIESEL',
                                price: dieselPrice,
                                icon: Icons.oil_barrel,
                                color: Colors.lightBlueAccent,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildFuelCard({
    required String title,
    required String price,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
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
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Icon(icon, color: color, size: 28),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            price,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Live Standard Rate',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
