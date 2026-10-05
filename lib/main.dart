import 'package0:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
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
      title: 'Fuel & Weather App',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
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
  // Weather API Key Added Here
  final String weatherApiKey = '42e264af50f9b2c516011c9467291294';

  String selectedCity = 'Lucknow';
  String temp = '--';
  String weatherCondition = 'Loading...';
  String petrolPrice = '--';
  String dieselPrice = '--';
  bool isLoading = false;

  final TextEditingController _cityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchByCityName(selectedCity);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  Future<void> fetchByCurrentLocation() async {
    setState(() => isLoading = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar('Kripya mobile me GPS / Location Services On karein.');
        setState(() => isLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar('Location permission deny kar di gayi hai.');
          setState(() => isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar('App Settings me jaakar Location permission manual allow karein.');
        setState(() => isLoading = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?lat=${position.latitude}&lon=${position.longitude}&units=metric&appid=$weatherApiKey',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _updateWeatherData(data);
        await _fetchLiveFuelPricesFromFirebase(selectedCity);
        _showSnackBar('Current Location: $selectedCity');
      } else {
        _showSnackBar('Location ka weather data load nahi ho saka.');
      }
    } catch (e) {
      _showSnackBar('GPS Location fetch karne me error aaya: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchByCityName(String cityName) async {
    if (cityName.trim().isEmpty) return;
    setState(() => isLoading = true);

    try {
      final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?q=$cityName&units=metric&appid=$weatherApiKey',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _updateWeatherData(data);
        await _fetchLiveFuelPricesFromFirebase(selectedCity);
      } else {
        _showSnackBar('City nahi mili. Sahi naam enter karein.');
      }
    } catch (e) {
      _showSnackBar('Network Error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _updateWeatherData(dynamic data) {
    setState(() {
      selectedCity = data['name'] ?? 'Unknown';
      temp = '${data['main']['temp'].round()}°C';
      weatherCondition = data['weather'][0]['main'] ?? '--';
    });
  }

  Future<void> _fetchLiveFuelPricesFromFirebase(String city) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('fuel_rates')
          .doc(city.toLowerCase())
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          petrolPrice = '₹${data['petrol'] ?? '--'}';
          dieselPrice = '₹${data['diesel'] ?? '--'}';
        });
      } else {
        setState(() {
          petrolPrice = 'N/A';
          dieselPrice = 'N/A';
        });
      }
    } catch (e) {
      setState(() {
        petrolPrice = 'Error';
        dieselPrice = 'Error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fuel & Weather Updates'),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => fetchByCityName(selectedCity),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _cityController,
                            decoration: InputDecoration(
                              hintText: 'City name enter karein...',
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.search, color: Colors.indigo),
                          onPressed: () {
                            fetchByCityName(_cityController.text);
                            _cityController.clear();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.my_location, color: Colors.indigo),
                          onPressed: fetchByCurrentLocation,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      selectedCity.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Weather', style: TextStyle(fontSize: 16, color: Colors.grey)),
                                const SizedBox(height: 5),
                                Text(temp, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                                Text(weatherCondition, style: const TextStyle(fontSize: 16, color: Colors.indigo)),
                              ],
                            ),
                            const Icon(Icons.wb_sunny, size: 50, color: Colors.orange),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            color: Colors.redAccent.shade100,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  const Text('Petrol Rate', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 10),
                                  Text(petrolPrice, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Card(
                            color: Colors.blueAccent.shade100,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  const Text('Diesel Rate', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 10),
                                  Text(dieselPrice, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
