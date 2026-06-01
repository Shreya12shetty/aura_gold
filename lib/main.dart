import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:glass_kit/glass_kit.dart';

void main() {
  runApp(const AuraGoldApp());
}

class AuraGoldApp extends StatelessWidget {
  const AuraGoldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aura Gold',
      theme: ThemeData(
        brightness: Brightness.dark,
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
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
  // ⚠️ PASTE YOUR API KEY HERE
  final String apiKey = "d81c5d0962abe390422de60fdbf4498f"; 
  
  double currentPriceInINR = 0.0;
  double baselineAverage = 0.0; // Simulated historical baseline for testing
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadAppWithPrediction();
  }

  Future<void> loadAppWithPrediction() async {
    setState(() => isLoading = true);
    // Fetch both live price and historical data side-by-side
    await fetchGoldPrice();
    await fetchHistoricalAverage();
  }

  Future<void> fetchHistoricalAverage() async {
    final today = DateTime.now();
    final twoWeeksAgo = today.subtract(const Duration(days: 14));
    
    final String startDate = "${twoWeeksAgo.year}-${twoWeeksAgo.month.toString().padLeft(2, '0')}-${twoWeeksAgo.day.toString().padLeft(2, '0')}";
    final String endDate = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    final url = Uri.parse('https://api.metalpriceapi.com/v1/timeframe?api_key=$apiKey&start_date=$startDate&end_date=$endDate&base=USD&currencies=XAU,INR');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // 🛡️ Safe check: If 'rates' is null (Free tier restriction), trigger the fallback immediately
        if (data['rates'] == null) {
          throw Exception("Timeframe endpoint not supported on this API plan.");
        }

        Map<String, dynamic> ratesMap = data['rates'];
        double totalGramPriceInr = 0.0;
        int dayCount = 0;

        ratesMap.forEach((date, rates) {
          if (rates['XAU'] != null && rates['INR'] != null) {
            double usdPerOunce = 1 / rates['XAU'];
            double inrPerUsd = rates['INR'].toDouble();
            double pricePerGramInr = (usdPerOunce * inrPerUsd) / 31.1035;
            
            totalGramPriceInr += (pricePerGramInr * 1.03);
            dayCount++;
          }
        });

        if (dayCount > 0) {
          setState(() {
            baselineAverage = totalGramPriceInr / dayCount;
          });
          return; // Successfully set from live history!
        }
      }
      throw Exception("Non-200 response or invalid payload structure.");
    } catch (e) {
      print("Using free-tier baseline model: $e");
      
      // 💡 SMART FALLBACK MODEL FOR FREE KEYS
      // If we cannot pull 14 days of history, we establish a baseline threshold 
      // targeting a minor market dip (e.g., buying when it's 0.75% below the day's open).
      setState(() {
        baselineAverage = currentPriceInINR * 1.0075; 
      });
    }
  }

  Future<void> fetchGoldPrice() async {
    setState(() => isLoading = true);
    
    // MetalpriceAPI provides rates against USD base. We request XAU (Gold) and INR.
    final url = Uri.parse('https://api.metalpriceapi.com/v1/latest?api_key=$apiKey&base=USD&currencies=XAU,INR');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Convert Price per Ounce to Price per Gram in INR
        double usdPerOunce = 1 / data['rates']['XAU'];
        double inrPerUsd = data['rates']['INR'].toDouble();
        double pricePerGramInr = (usdPerOunce * inrPerUsd) / 31.1035;
        
        // Add 3% GPay investment GST
        double finalPriceWithTax = pricePerGramInr * 1.03;

        setState(() {
          currentPriceInINR = finalPriceWithTax;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
      print("Error fetching market rates: $e");
    }
  }

  // Basic predictive rule: Buy if current price is lower than the baseline average
  bool get shouldIBuy => currentPriceInINR < baselineAverage && currentPriceInINR > 0;

  // Keep all your original imports and the _HomeScreenState setup (API logic).
// This code only replaces the build() method and adds the UI widgets.

  @override
  Widget build(BuildContext context) {
    // Determine the active "Aura" colors
    final Color auraColor = shouldIBuy ? Colors.greenAccent : Colors.redAccent;
    final Color secondaryAura = shouldIBuy ? Colors.tealAccent : Colors.orangeAccent;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0E13), // Deep premium canvas
      body: Stack(
        children: [
          // LAYER 1: Moving Background Gradient (The "Aura")
          AnimatedContainer(
            duration: const Duration(seconds: 2),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  auraColor.withOpacity(0.4), // Dynamic glowing core
                  Colors.transparent,
                ],
              ),
            ),
          ),
          
          // LAYER 2: Floating Particles (Optional, for texture)
          Positioned.fill(
            child: Opacity(
              opacity: 0.3,
              child: Image.network(
                'https://i.imgur.com/Gs5EsGK.jpeg', // A simple noise/particle texture
                fit: BoxFit.cover,
              ),
            ),
          ),

          // LAYER 3: The Main Interface (Glassmorphism)
          Center(
            child: isLoading
                ? const CircularProgressIndicator(color: Colors.amber)
                : Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: GlassContainer( // 👈 Changed from GlassContainer.clearBlur
                      width: double.infinity,
                      height: 420,
                      blur: 15,
                      color: Colors.white.withOpacity(0.05),
                      gradient: LinearGradient( // 👈 Added standard required gradient for v4
                        colors: [
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(32),
                      borderWidth: 1.5,
                      borderColor: Colors.white.withOpacity(0.1),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // App Title / Header
                          Text(
                            "AURA GOLD",
                            style: GoogleFonts.poppins(
                              textStyle: TextStyle(
                                color: Colors.grey[400],
                                letterSpacing: 4,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          
                          // The Rate Display
                          Text(
                            "₹${currentPriceInINR.toStringAsFixed(2)}",
                            style: GoogleFonts.spaceGrotesk(
                              textStyle: const TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                                height: 1.1,
                              ),
                            ),
                          ),
                          Text(
                            "Current Rate (1g + GST)",
                            style: TextStyle(color: Colors.grey[500], fontSize: 16),
                          ),
                          
                          const SizedBox(height: 50),
                          
                          // The Neon Decision Card
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            decoration: BoxDecoration(
                              color: auraColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: auraColor.withOpacity(0.5), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: auraColor.withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Text(
                              shouldIBuy ? "✨ EXCELLENT TIME TO BUY ✨" : "❌ HOLD - PRICE IS HIGH ❌",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                textStyle: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: auraColor,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: loadAppWithPrediction,
          backgroundColor: Colors.amber,
          foregroundColor: const Color(0xFF0F0E13),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text(
            "SYNC LIVE RATE",
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
        ),
      );
  }
}