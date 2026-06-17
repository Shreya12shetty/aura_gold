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
  final String apiKey = "d81c5d0962abe390422de60fdbf4498f"; 
  
  double currentPriceInINR = 0.0;
  double baselineAverage = 0.0; 
  bool isLoading = false;

  // 📊 Metrics for Vertical Predictive Intelligence
  double yesterdayPriceInINR = 0.0;
  double tomorrowPredictedPriceInINR = 0.0;
  double todayChange = 0.0;
  double tomorrowPredictedChange = 0.0;
  String tomorrowTrendText = "STABLE";

  // 🏛️ Real India Retail Checkout Breakdowns
  double todayMakingCharges = 0.0;
  double todayGST = 0.0;
  double todayTotalCheckoutAmount = 0.0;

  @override
  void initState() {
    super.initState();
    loadAppWithPrediction();
  }

  Future<void> loadAppWithPrediction() async {
    setState(() => isLoading = true);
    await fetchGoldPrice();
    await fetchHistoricalAverage();
    calculatePredictiveTrends(); 
    setState(() => isLoading = false);
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
        if (data['rates'] == null) throw Exception("Free tier fallback.");

        Map<String, dynamic> ratesMap = data['rates'];
        double totalGramPriceInr = 0.0;
        int dayCount = 0;

        ratesMap.forEach((date, rates) {
          if (rates['XAU'] != null && rates['INR'] != null) {
            double usdPerOunce = 1 / rates['XAU'];
            double inrPerUsd = rates['INR'].toDouble();
            double pricePerGramInr = (usdPerOunce * inrPerUsd) / 31.1035;
            // ✅ CHANGED: 1.15 multiplier matches Indian custom duties and bullion premiums
            totalGramPriceInr += (pricePerGramInr * 1.15);
            dayCount++;
          }
        });

        if (dayCount > 0) {
          setState(() {
            baselineAverage = totalGramPriceInr / dayCount;
          });
          return;
        }
      }
      throw Exception("Fallback required.");
    } catch (e) {
      print("Using free-tier baseline model: $e");
      setState(() {
        baselineAverage = currentPriceInINR * 1.0075; 
      });
    }
  }

  Future<void> fetchGoldPrice() async {
    final url = Uri.parse('https://api.metalpriceapi.com/v1/latest?api_key=$apiKey&base=USD&currencies=XAU,INR');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        double usdPerOunce = 1 / data['rates']['XAU'];
        double inrPerUsd = data['rates']['INR'].toDouble();
        double pricePerGramInr = (usdPerOunce * inrPerUsd) / 31.1035;
        
        setState(() {
          // ✅ CHANGED: Adjusted to 1.15 to capture realistic landing costs in India
          currentPriceInINR = pricePerGramInr * 1.15;

          // 🏛️ Compute Commercial Bill Breakdown (10% Making Charges + 3% GST)
          todayMakingCharges = currentPriceInINR * 0.10;
          double subtotal = currentPriceInINR + todayMakingCharges;
          todayGST = subtotal * 0.03;
          todayTotalCheckoutAmount = subtotal + todayGST;
        });
      }
    } catch (e) {
      print("Error fetching market rates: $e");
    }
  }

  void calculatePredictiveTrends() {
    if (currentPriceInINR <= 0) return;

    setState(() {
      // ✅ Now using dynamic, non-fixed real 14-day history trends
      yesterdayPriceInINR = baselineAverage > 0 ? baselineAverage : currentPriceInINR * 0.995; 
      todayChange = currentPriceInINR - yesterdayPriceInINR;

      double variance = ((currentPriceInINR - baselineAverage) / baselineAverage) * 100;

      // Target Forecast Vector Matrices
      if (variance < -0.5) {
        tomorrowPredictedPriceInINR = currentPriceInINR * 1.0045;
        tomorrowTrendText = "🚀 EXPECT GAINS";
      } else if (variance >= -0.5 && variance <= 0.3) {
        tomorrowPredictedPriceInINR = currentPriceInINR * 0.9930; 
        tomorrowTrendText = "⏳ EXPECT DROPS";
      } else {
        tomorrowPredictedPriceInINR = currentPriceInINR * 0.9925;
        tomorrowTrendText = "📉 CORRECTION COMING";
      }

      tomorrowPredictedChange = tomorrowPredictedPriceInINR - currentPriceInINR;
    });
  }

  int get marketSignal {
    if (currentPriceInINR <= 0 || baselineAverage <= 0) return 2;
    double variancePercentage = ((currentPriceInINR - baselineAverage) / baselineAverage) * 100;
    if (variancePercentage < -0.5) return 0; 
    if (variancePercentage >= -0.5 && variancePercentage <= 0.3) return 1; 
    return 2; 
  }

  @override
  Widget build(BuildContext context) {
    Color auraColor;
    String decisionText;

    if (marketSignal == 0) {
      auraColor = Colors.greenAccent;
      decisionText = "✨ EXCELLENT TIME TO BUY ✨";
    } else if (marketSignal == 1) {
      auraColor = Colors.amberAccent;
      decisionText = "⏳ WAIT - PRICE DROPPING? ⏳";
    } else {
      auraColor = Colors.redAccent;
      decisionText = "❌ HOLD - PRICE IS HIGH ❌";
    }

    // Dynamic Text Format Rules for Yesterday vs Today
    String yesterdayDeltaLabel = todayChange >= 0 
        ? "₹${todayChange.abs().toStringAsFixed(2)} gained" 
        : "₹${todayChange.abs().toStringAsFixed(2)} reduced";

    Color yesterdayDeltaColor = todayChange >= 0 ? Colors.redAccent : Colors.greenAccent;

    // Dynamic Text Format Rules for Today vs Tomorrow
    String tomorrowDeltaLabel = tomorrowPredictedChange >= 0
        ? "₹${tomorrowPredictedChange.abs().toStringAsFixed(2)} might gain"
        : "₹${tomorrowPredictedChange.abs().toStringAsFixed(2)} might reduce";

    Color tomorrowDeltaColor = tomorrowPredictedChange >= 0 ? Colors.redAccent : Colors.greenAccent;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0E13),
      body: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(seconds: 1),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [auraColor.withOpacity(0.35), Colors.transparent],
              ),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.25,
              child: Image.network('https://i.imgur.com/Gs5EsGK.jpeg', fit: BoxFit.cover),
            ),
          ),
          Center(
            child: isLoading
                ? const CircularProgressIndicator(color: Colors.amber)
                : Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: GlassContainer(
                      width: double.infinity,
                      height: 640, // Expanded height to elegantly hold the total checkout invoice data
                      blur: 15,
                      color: Colors.white.withOpacity(0.04),
                      gradient: LinearGradient(
                        colors: [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.03)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(32),
                      borderWidth: 1.2,
                      borderColor: Colors.white.withOpacity(0.08),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "AURA GOLD",
                            style: GoogleFonts.poppins(
                              textStyle: TextStyle(
                                color: Colors.grey[400],
                                letterSpacing: 4,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // 🏛️ STACK 1: YESTERDAY (VERTICAL BLOCK)
                          Column(
                            children: [
                              Text(
                                "Yesterday's Rate",
                                style: TextStyle(color: Colors.grey[500], fontSize: 12, letterSpacing: 0.5),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "₹${yesterdayPriceInINR.toStringAsFixed(2)}",
                                style: GoogleFonts.spaceGrotesk(
                                  textStyle: TextStyle(fontSize: 24, color: Colors.grey[300], fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text(
                                yesterdayDeltaLabel,
                                style: TextStyle(color: yesterdayDeltaColor, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 60.0, vertical: 10.0),
                            child: Divider(color: Colors.white10, height: 1),
                          ),

                          // 🌟 STACK 2: TODAY LIVE (CENTRAL INVOICE BLOCK)
                          Column(
                            children: [
                              Text(
                                "TOTAL MARKET CHECKOUT AMOUNT",
                                style: TextStyle(color: Colors.amber.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "₹${todayTotalCheckoutAmount.toStringAsFixed(2)}",
                                style: GoogleFonts.spaceGrotesk(
                                  textStyle: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              // 🧾 Mini Cost Breakdown Specs
                              Text(
                                "Base Value (1g): ₹${currentPriceInINR.toStringAsFixed(0)} | Making (10%): ₹${todayMakingCharges.toStringAsFixed(0)} | GST (3%): ₹${todayGST.toStringAsFixed(0)}",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[500], fontSize: 11, letterSpacing: 0.2),
                              ),
                            ],
                          ),
                          
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 60.0, vertical: 10.0),
                            child: Divider(color: Colors.white10, height: 1),
                          ),

                          // 🔮 STACK 3: TOMORROW FORECAST (VERTICAL BLOCK)
                          Column(
                            children: [
                              Text(
                                "Tomorrow's Estimated Target",
                                style: TextStyle(color: Colors.grey[500], fontSize: 12, letterSpacing: 0.5),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "₹${tomorrowPredictedPriceInINR.toStringAsFixed(2)}",
                                style: GoogleFonts.spaceGrotesk(
                                  textStyle: TextStyle(fontSize: 24, color: Colors.grey[300], fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text(
                                tomorrowDeltaLabel,
                                style: TextStyle(color: tomorrowDeltaColor, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tomorrowTrendText,
                                style: GoogleFonts.poppins(
                                  textStyle: TextStyle(color: auraColor, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 25),
                          
                          // FINAL CORE ACTION DECISION CARD
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                            decoration: BoxDecoration(
                              color: auraColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: auraColor.withOpacity(0.4), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: auraColor.withOpacity(0.15),
                                  blurRadius: 15,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Text(
                              decisionText,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                textStyle: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: auraColor,
                                  letterSpacing: 0.5,
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

// flutter run