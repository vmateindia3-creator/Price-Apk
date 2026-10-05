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

  String selectedCity = 'Lucknow';
  double rawTemp = 25.0;
  String tempDisplay = '--°C';
  String weatherCondition = 'Loading...';
  String weatherDescription = 'Fetching data...';
  String weatherIcon = '01d';
  String petrolPrice = 'Fetching...';
  String dieselPrice = 'Fetching...';
  bool isLoading = false;

  final TextEditingController _cityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchDataForCity(selectedCity);
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Dynamic Background Gradient based on Temperature
  List<Color> _getTemperatureGradient() {
    if (rawTemp <= 15.0) {
      // Cold / Snow
      return [const Color(0xFF1E3C72), const Color(0xFF2A5298)];
    } else if (rawTemp > 15.0 && rawTemp <= 30.0) {
      // Pleasant / Mild
      return [const Color(0xFF11998E), const Color(0xFF38EF7D)];
    } else {
      // Warm / Hot
      return [const Color(0xFFFF512F), const Color(0xFFDD2476)];
    }
  }

  // GPS Location Fetching
  Future<void> fetchByCurrentLocation() async {
    setState(() => isLoading = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar('Kripya mobile ka GPS / Location ON karein.');
        setState(() => isLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar('Location permission deny ho gayi.');
          setState(() => isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar('Settings me jaakar App Location permission Allow karein.');
        setState(() => isLoading = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
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
        _showSnackBar('GPS Location weather data load nahi kar saka.');
      }
    } catch (e) {
      _showSnackBar('GPS Fetching me problem aayi: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // Search by City Name
  Future<void> fetchDataForCity(String cityName) async {
    if (cityName.trim().isEmpty) return;
    setState(() => isLoading = true);

    try {
      final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?q=${cityName.trim()}&units=metric&appid=$weatherApiKey',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _updateWeatherData(data);
        await _fetchLiveFuelPricesFromFirebase(selectedCity);
      } else {
        _showSnackBar('City nahi mili! Sahi naam enter karein.');
      }
    } catch (e) {
      _showSnackBar('Network Connection Check Karein.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _updateWeatherData(dynamic data) {
    setState(() {
      selectedCity = data['name'] ?? 'Unknown';
      rawTemp = (data['main']['temp'] as num).toDouble();
      tempDisplay = '${rawTemp.round()}°C';
      weatherCondition = data['weather'][0]['main'] ?? '--';
      weatherDescription = data['weather'][0]['description'] ?? '';
      weatherIcon = data['weather'][0]['icon'] ?? '01d';
    });
  }

  // Live Fuel Rates Fetching from Firestore
  Future<void> _fetchLiveFuelPricesFromFirebase(String city) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('fuel_rates')
          .doc(city.toLowerCase().trim())
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          petrolPrice = '₹${data['petrol'] ?? '--'}';
          dieselPrice = '₹${data['diesel'] ?? '--'}';
        });
      } else {
        // Default Fallback
        setState(() {
          petrolPrice = '₹96.72';
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
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _getTemperatureGradient(),
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : RefreshIndicator(
                  onRefresh: () => fetchDataForCity(selectedCity),
                  color: Colors.white,
                  backgroundColor: Colors.black26,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Search Bar Section
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search, color: Colors.white),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _cityController,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                                  decoration: constPoori app ko ek dynamic, modern UI aur robust error handling ke saath rewrite kar dete hain. 

Aapki zarooraton ke mutabiq naye features:
1. **Dynamic Backgrounds:** Temperature aur mausam ke hisab se UI ka gradient aur background dynamic badlega (Jaise Heatwave, Cold/Pleasant, Rain/Storm, Clear Sky).
2. **GPS & City Location Fetch:** `geolocator` plus Geocoding API se exact location/city fetch hogi.
3. **Robust API & Firestore Fallback:** Weather API, OpenWeather Reverse Geocoding, aur Firebase Fuel Firestore syncing ka fail-safe handling.
4. **Modern Glassmorphic UI:** Smooth cards, clean typography, custom weather icons, elevation shadows.

---

### File 1: `android/app/src/main/AndroidManifest.xml`
Sabse pehle ye permissions aur themes verify/replace kar lijiye taaki GPS aur network request blocks na ho:

```xml
<manifest xmlns:android="[http://schemas.android.com/apk/res/android](http://schemas.android.com/apk/res/android)">

    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

    <application
        android:label="Fuel & Weather"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
                                  
