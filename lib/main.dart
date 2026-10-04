import 'package:flutter/material.dart';

// 1. Strongly-Typed Data Model
final class CityData {
  final String temperature;
  final String condition;
  final String humidity;
  final double petrol;
  final double diesel;
  final double cng;
  final List<Color> bgGradient;
  final IconData weatherIcon;

  const CityData({
    required this.temperature,
    required this.condition,
    required this.humidity,
    required this.petrol,
    required this.diesel,
    required this.cng,
    required this.bgGradient,
    required this.weatherIcon,
  });
}

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
        primaryColor: const Color(0xFF008069), // WhatsApp Emerald Green
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
  String selectedCity = 'Delhi';
  bool isLoading = false;
  double fuelAmountInput = 500;

  // 2. Dynamic City & Weather Data Store
  static const Map<String, CityData> cityDataMap = {
    'Delhi': CityData(
      temperature: '32°C',
      condition: 'Sunny Day',
      humidity: '55%',
      petrol: 96.72,
      diesel: 89.62,
      cng: 75.59,
      bgGradient: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
      weatherIcon: Icons.wb_sunny_rounded,
    ),
    'Mumbai': CityData(
      temperature: '30°C',
      condition: 'Humid & Breeze',
      humidity: '78%',
      petrol: 104.21,
      diesel: 92.15,
      cng: 76.00,
      bgGradient: [Color(0xFFE0F7FA), Color(0xFFB2EBF2)],
      weatherIcon: Icons.water_drop_rounded,
    ),
    'Lucknow': CityData(
      temperature: '34°C',
      condition: 'Partly Cloudy',
      humidity: '60%',
      petrol: 96.57,
      diesel: 89.76,
      cng: 82.50,
      bgGradient: [Color(0xFFECEFF1), Color(0xFFCFD8DC)],
      weatherIcon: Icons.wb_cloudy_rounded,
    ),
    'Kanpur': CityData(
      temperature: '33°C',
      condition: 'Clear Sky',
      humidity: '58%',
      petrol: 96.63,
      diesel: 89.81,
      cng: 82.50,
      bgGradient: [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
      weatherIcon: Icons.wb_twilight_rounded,
    ),
  };

  Future<void> refreshData() async {
    setState(() => isLoading = true);
    await Future.delayed(const Duration(milliseconds: 700));
    setState(() => isLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF008069),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Text('$selectedCity ka rate & weather sync ho gaya!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = cityDataMap[selectedCity]!;
    final liters = (fuelAmountInput / data.petrol).toStringAsFixed(2);

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
            onPressed: isLoading ? null : refreshData,
          ),
        ],
      ),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: data.bgGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                children: [
                  // 1. WhatsApp-Style City Selector Card
                  Card(
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.my_location_rounded, color: Color(0xFF008069)),
                          const SizedBox(width: 12),
                          const Text(
                            'Select City:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedCity,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF008069)),
                                items: cityDataMap.keys.map((String city) {
                                  return DropdownMenuItem<String>(
                                    value: city,
                                    child: Text(
                                      city,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (newCity) {
                                  if (newCity != null) {
                                    setState(() => selectedCity = newCity);
                                  }
                                },
                              ),
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
                          Column(
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
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                data.temperature,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 38,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${data.condition}  |  Humidity: ${data.humidity}',
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                          Icon(data.weatherIcon, color: const Color(0xFFFFD54F), size: 54),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Fuel Rates Tiles
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'Today Fuel Rates',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF121B22)),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(child: _buildFuelTile('Petrol', '₹${data.petrol.toStringAsFixed(2)}', '/Ltr', const Color(0xFFE65100))),
                      const SizedBox(width: 8),
                      Expanded(child: _buildFuelTile('Diesel', '₹${data.diesel.toStringAsFixed(2)}', '/Ltr', const Color(0xFF37474F))),
                      const SizedBox(width: 8),
                      Expanded(child: _buildFuelTile('CNG', '₹${data.cng.toStringAsFixed(2)}', '/Kg', const Color(0xFF2E7D32))),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 4. Interactive Calculator Card
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
                const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'Today Fuel Rates',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF121B22)),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(child: _buildFuelTile('Petrol', '₹${data.petrol.toStringAsFixed(2)}', '/Ltr', const Color(0xFFE65100))),
                      const SizedBox(width: 8),
                      Expanded(child: _buildFuelTile('Diesel', '₹${data.diesel.toStringAsFixed(2)}', '/Ltr', const Color(0xFF37474F))),
                      const SizedBox(width: 8),
                      Expanded(child: _buildFuelTile('CNG', '₹${data.cng.toStringAsFixed(2)}', '/Kg', const Color(0xFF2E7D32))),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 4. Interactive Calculator Card (WhatsApp Green Chat Bubble Theme)
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
                              color: const Color(0xFFE7FCE3), // WhatsApp Light Green Chat Bubble
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
          ],
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
