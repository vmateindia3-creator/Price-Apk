import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'dart:convert';

// OpenWeatherMap API Key
const String weatherApiKey = '42e264af50f9b2c516011c9467291294';

void main() {
  runApp(const FuelTempApp());
}

class FuelTempApp extends StatelessWidget {
  const FuelTempApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fuel & Weather Live',
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF008069),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF008069),
          primary: const Color(0xFF008069),
          secondary: const Color(0xFF25D366),
        ),
      ),
      home: const ResponsiveDashboard(),
    );
  }
}

class ResponsiveDashboard extends StatefulWidget {
  const ResponsiveDashboard({super.key});

  @override
  State<ResponsiveDashboard> createState() => _ResponsiveDashboardState();
}

class _ResponsiveDashboardState extends State<ResponsiveDashboard> {
  final TextEditingController _searchController = TextEditingController();

  String selectedCity = 'Delhi';
  String temperature = '32°C';
  String condition = 'Clear Sky';
  String humidity = '55%';
  String windSpeed = '3.5 m/s';
  IconData weatherIcon = Icons.wb_sunny_rounded;

  bool isLoading = false;
  double fuelAmountInput = 500;

  // Reference Fuel Rates Data (Fallback by City)
  final Map<String, Map<String, double>> fuelRates = {
    'Delhi': {'petrol': 96.72, 'diesel': 89.62, 'cng': 75.59},
    'Mumbai': {'petrol': 104.21, 'diesel': 92.15, 'cng': 76.00},
    'Lucknow': {'petrol': 96.57, 'diesel': 89.76, 'cng': 82.50},
    'Kanpur': {'petrol': 96.63, 'diesel': 89.81, 'cng': 82.50},
  };

  @override
  void initState() {
    super.initState();
    fetchWeatherByCity(selectedCity);
  }

  // 1. Fetch Weather by City Name
  Future<void> fetchWeatherByCity(String queryCity) async {
    if (queryCity.trim().isEmpty) return;

    setState(() => isLoading = true);

    final url = Uri.parse(
      'https://api.openweathermap.org/data/2.5/weather?q=${queryCity.trim()}&units=metric&appid=$weatherApiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _updateWeatherData(data);
      } else {
        _showSnackBar('City not found! Please check spelling.');
      }
    } catch (e) {
      _showSnackBar('Network error! Please check connection.');
    } finally {
      setState(() => isLoading = false);
    }
  }

  // 2. Fetch Weather by Current GPS Location
  Future<void> fetchWeatherByCurrentLocation() async {
    setState(() => isLoading = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar('Please turn on GPS/Location in device settings.');
        setState(() => isLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar('Location permission denied.');
          setState(() => isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar('Location permission permanently denied. Enable in app settings.');
        setState(() => isLoading = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?lat=${position.latitude}&lon=${position.longitude}&units=metric&appid=$weatherApiKey',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _updateWeatherData(data);
        _showSnackBar('Current location auto-detected!');
      } else {
        _showSnackBar('Unable to fetch weather for current location.');
      }
    } catch (e) {
      _showSnackBar('Failed to detect GPS location.');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _updateWeatherData(dynamic data) {
    setState(() {
      selectedCity = data['name'] ?? 'Unknown';
      _searchController.text = selectedCity;
      temperature = '${(data['main']['temp'] as num).round()}°C';
      condition = data['weather'][0]['description'].toString().toUpperCase();
      humidity = '${data['main']['humidity']}%';
      windSpeed = '${data['wind']['speed']} m/s';
      weatherIcon = _getWeatherIcon(data['weather'][0]['main']);
    });
  }

  IconData _getWeatherIcon(String? mainCondition) {
    switch (mainCondition?.toLowerCase()) {
      case 'clouds':
        return Icons.wb_cloudy_rounded;
      case 'rain':
      case 'drizzle':
        return Icons.water_drop_rounded;
      case 'thunderstorm':
        return Icons.thunderstorm_rounded;
      case 'clear':
        return Icons.wb_sunny_rounded;
      case 'snow':
        return Icons.ac_unit_rounded;
      case 'mist':
      case 'fog':
      case 'haze':
        return Icons.grain_rounded;
      default:
        return Icons.wb_twilight_rounded;
    }
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF008069),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Lookup fuel rates or fallback to Delhi default rates
    final currentPetrol = fuelRates[selectedCity]?['petrol'] ?? 96.72;
    final currentDiesel = fuelRates[selectedCity]?['diesel'] ?? 89.62;
    final currentCng = fuelRates[selectedCity]?['cng'] ?? 75.59;

    final liters = (fuelAmountInput / currentPetrol).toStringAsFixed(2);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF008069),
        elevation: 2,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_gas_station, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Fuel & Weather Live',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 19),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded, color: Colors.white),
            onPressed: isLoading ? null : () => fetchWeatherByCity(selectedCity),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
              children: [
                // 1. City Search Bar & GPS Auto Detect Button
                Card(
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            textInputAction: TextInputAction.search,
                            decoration: const InputDecoration(
                              hintText: 'Search city (e.g. Kanpur, Lucknow)...',
                              border: InputBorder.none,
                              prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF008069)),
                            ),
                            onSubmitted: (val) => fetchWeatherByCity(val),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF008069)),
                          onPressed: () => fetchWeatherByCity(_searchController.text),
                        ),
                        const SizedBox(width: 4),
                        Tooltip(
                          message: 'Auto-detect GPS Location',
                          child: IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFE8F5E9),
                            ),
                            icon: const Icon(Icons.my_location_rounded, color: Color(0xFF008069)),
                            onPressed: fetchWeatherByCurrentLocation,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 2. Weather Highlight Card
                Card(
                  elevation: 2,
                  color: const Color(0xFF075E54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Live Weather • $selectedCity',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                temperature,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 38,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '$condition  |  Humidity: $humidity',
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Wind Speed: $windSpeed',
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Icon(weatherIcon, color: const Color(0xFFFFD54F), size: 54),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Fuel Rates Section
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'Today Fuel Rates',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF121B22)),
                  ),
                ),
                Row(
                  children: [
                    Expanded(child: _buildFuelTile('Petrol', '₹${currentPetrol.toStringAsFixed(2)}', '/Ltr', const Color(0xFFE65100))),
                    const SizedBox(width: 8),
                    Expanded(child: _buildFuelTile('Diesel', '₹${currentDiesel.toStringAsFixed(2)}', '/Ltr', const Color(0xFF37474F))),
                    const SizedBox(width: 8),
                    Expanded(child: _buildFuelTile('CNG', '₹${currentCng.toStringAsFixed(2)}', '/Kg', const Color(0xFF2E7D32))),
                  ],
                ),
                const SizedBox(height: 16),

                // 4. Quick Fuel Estimator
                Card(
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.calculate_outlined, color: Color(0xFF008069)),
                            SizedBox(width: 8),
                            Text(
                              'Quick Fuel Estimator',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Budget Amount:', style: TextStyle(color: Colors.black87)),
                            Text(
                              '₹${fuelAmountInput.toInt()}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF008069)),
                            ),
                          ],
                        ),
                        Slider(
                          value: fuelAmountInput,
                          min: 100,
                          max: 3000,
                          divisions: 29,
                          activeColor: const Color(0xFF008069),
                          inactiveColor: const Color(0xFFE0E0E0),
                          label: '₹${fuelAmountInput.toInt()}',
                          onChanged: (val) => setState(() => fuelAmountInput = val),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7FCE3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFB9F6CA)),
                          ),
                          child: Text(
                            '₹${fuelAmountInput.toInt()} me $selectedCity me approx $liters Ltr Petrol aayega.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF075E54),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFuelTile(String title, String price, String unit, Color accentColor) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Text(title, style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            Text(price, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(unit, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
