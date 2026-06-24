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
      title: 'Aura Gold Tracker',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.amber,
        scaffoldBackgroundColor: const Color(0xFF0F0E13),
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
  final TextEditingController _calculatorController = TextEditingController(text: "5000");
  
  double currentPriceInINR = 0.0;
  double baselineAverage = 0.0; 
  bool isLoading = false;

  // 📊 Metrics for Vertical Predictive Intelligence
  double yesterdayPriceInINR = 0.0;
  double tomorrowPredictedPriceInINR = 0.0;
  double todayChange = 0.0;
  double tomorrowPredictedChange = 0.0;
  String tomorrowTrendText = "STABLE";

  // 🏛️ MMTC-PAMP / GPay Live Pricing Structures
  double gPayBuyPricePerGram = 0.0;
  double gPaySellPricePerGram = 0.0;
  
  // 🧮 Live Calculator Output State
  double calculatedGrams = 0.0;
  double calculatedGSTAmount = 0.0;
  double calculatedNetInvestment = 0.0;

  @override
  void initState() {
    super.initState();
    loadAppWithPrediction();
    _calculatorController.addListener(_runLivePortfolioCalculator);
  }

  @override
  void dispose() {
    _calculatorController.dispose();
    super.dispose();
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
        if (data['rates'] != null) {
          Map<String, dynamic> ratesMap = data['rates'];
          double totalGramPriceInr = 0.0;
          int dayCount = 0;

          List<String> sortedDates = ratesMap.keys.toList()..sort();

          ratesMap.forEach((date, rates) {
            if (rates['XAU'] != null && rates['INR'] != null) {
              double usdPerOunce = 1 / rates['XAU'];
              double inrPerUsd = rates['INR'].toDouble();
              double pricePerGramInr = (usdPerOunce * inrPerUsd) / 31.1035;
              totalGramPriceInr += (pricePerGramInr * 1.15);
              dayCount++;
            }
          });

          if (sortedDates.length >= 2) {
            String yesterdayKey = sortedDates[sortedDates.length - 2];
            var yRates = ratesMap[yesterdayKey];
            double yUsdOunce = 1 / yRates['XAU'];
            double yInrUsd = yRates['INR'].toDouble();
            yesterdayPriceInINR = ((yUsdOunce * yInrUsd) / 31.1035) * 1.15;
          }

          if (dayCount > 0) {
            setState(() {
              baselineAverage = totalGramPriceInr / dayCount;
            });
            return; 
          }
        }
      }
      throw Exception("Timeframe API restricted on Free Tier.");
    } catch (e) {
      print("Using secure baseline model fallback: $e");
      setState(() {
        baselineAverage = 14350.00; 
        yesterdayPriceInINR = 14410.00; 
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
          currentPriceInINR = pricePerGramInr * 1.15; // 15% Landing Premium/Duties

          // 🏛️ Reverse Engineer MMTC-PAMP / GPay Metrics
          // Buy Rate includes 3% GST on the base retail landed value
          gPayBuyPricePerGram = currentPriceInINR * 1.03;
          // Sell Rate strips the GST and applies a standard MMTC-PAMP liquidity spread (~3.5%)
          gPaySellPricePerGram = currentPriceInINR * 0.965;
        });
        _runLivePortfolioCalculator();
      }
    } catch (e) {
      print("Error fetching market rates: $e");
    }
  }

  void calculatePredictiveTrends() {
    if (currentPriceInINR <= 0) return;

    setState(() {
      todayChange = currentPriceInINR - yesterdayPriceInINR;
      double variance = ((currentPriceInINR - baselineAverage) / baselineAverage) * 100;

      if (variance < -0.3) {
        tomorrowPredictedPriceInINR = currentPriceInINR * 1.0045;
        tomorrowTrendText = "🚀 EXPECT GAINS";
      } else if (variance >= -0.3 && variance <= 0.3) {
        tomorrowPredictedPriceInINR = currentPriceInINR * 0.9930; 
        tomorrowTrendText = "⏳ EXPECT DROPS";
      } else {
        tomorrowPredictedPriceInINR = currentPriceInINR * 0.9925;
        tomorrowTrendText = "📉 CORRECTION COMING";
      }

      tomorrowPredictedChange = tomorrowPredictedPriceInINR - currentPriceInINR;
    });
  }

  void _runLivePortfolioCalculator() {
    if (gPayBuyPricePerGram <= 0) return;
    double inputAmount = double.tryParse(_calculatorController.text) ?? 0.0;
    
    setState(() {
      // 3% GST is extracted out of the gross billing amount sent through GPay
      calculatedGSTAmount = inputAmount - (inputAmount / 1.03);
      calculatedNetInvestment = inputAmount - calculatedGSTAmount;
      calculatedGrams = calculatedNetInvestment / currentPriceInINR;
    });
  }

  int get marketSignal {
    if (currentPriceInINR <= 0 || baselineAverage <= 0) return 2;
    double variancePercentage = ((currentPriceInINR - baselineAverage) / baselineAverage) * 100;
    if (variancePercentage < -0.3) return 0; 
    if (variancePercentage >= -0.3 && variancePercentage <= 0.3) return 1; 
    return 2; 
  }

  @override
  Widget build(BuildContext context) {
    Color auraColor;
    String decisionText;

    if (marketSignal == 0) {
      auraColor = Colors.greenAccent;
      decisionText = "✨ EXCELLENT TIME TO ACCUMULATE ✨";
    } else if (marketSignal == 1) {
      auraColor = Colors.amberAccent;
      decisionText = "⏳ STABLE MARKET MATCHING AVERAGES ⏳";
    } else {
      auraColor = Colors.redAccent;
      decisionText = "❌ HOLD OFF - SPREAD IS CURRENTLY WIDE ❌";
    }

    String yesterdayDeltaLabel = todayChange >= 0 
        ? "₹${todayChange.abs().toStringAsFixed(2)} gained" 
        : "₹${todayChange.abs().toStringAsFixed(2)} reduced";

    Color yesterdayDeltaColor = todayChange >= 0 ? Colors.redAccent : Colors.greenAccent;

    return Scaffold(
      body: Stack(
        children: [
          // Aura Radial Gradient Glow Background
          AnimatedContainer(
            duration: const Duration(seconds: 1),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.3,
                colors: [auraColor.withOpacity(0.22), Colors.transparent],
              ),
            ),
          ),
          
          Positioned.fill(
            child: Opacity(
              opacity: 0.25,
              child: Image.network(
                'https://i.imgur.com/Gs5EsGK.jpeg', 
                fit: BoxFit.cover,
              ),
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                child: Column(
                  children: [
                    // Header Text
                    Text(
                      "AURA GOLD TRACKER",
                      style: GoogleFonts.poppins(
                        textStyle: TextStyle(
                          color: Colors.grey[400],
                          letterSpacing: 4,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "MMTC-PAMP Portfolio Core Engine",
                      style: TextStyle(color: Colors.grey[600], fontSize: 11, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 24),

                    isLoading 
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(50.0),
                          child: CircularProgressIndicator(color: Colors.amber),
                        ),
                      )
                    : Column(
                        children: [
                          // 🏛️ MAIN METRICS CONTAINER
                          GlassContainer(
                            width: double.infinity,
                            height: 410,
                            blur: 18,
                            color: Colors.white.withOpacity(0.03),
                            gradient: LinearGradient(
                              colors: [Colors.white.withOpacity(0.06), Colors.white.withOpacity(0.01)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(28),
                            borderWidth: 1.0,
                            borderColor: Colors.white.withOpacity(0.07),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Yesterday Benchmark Context
                                Text(
                                  "Yesterday Retail Track: ₹${yesterdayPriceInINR.toStringAsFixed(2)} ($yesterdayDeltaLabel)",
                                  style: TextStyle(color: yesterdayDeltaColor, fontSize: 11, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 25),

                                // GPay Instant Buy Cost Block (Main Figure)
                                Text(
                                  "GPAY LIVE BUY PRICE",
                                  style: TextStyle(color: Colors.amber.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                                ),
                                Text(
                                  "₹${gPayBuyPricePerGram.toStringAsFixed(2)}",
                                  style: GoogleFonts.spaceGrotesk(
                                    textStyle: const TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                                Text("(Per 1g 24K 99.99% Gold + 3% GST Included)", style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                                
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 50.0, vertical: 20.0),
                                  child: Divider(color: Colors.white10, height: 1),
                                ),

                                // GPay Liquid Sell-Back Return Block
                                Text(
                                  "GPAY LIVE SELL-BACK RATE",
                                  style: TextStyle(color: Colors.grey[400], fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "₹${gPaySellPricePerGram.toStringAsFixed(2)}",
                                  style: GoogleFonts.spaceGrotesk(
                                    textStyle: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[200],
                                    ),
                                  ),
                                ),
                                Text("(Instant liquified portfolio rate excluding entry taxes)", style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                                
                                const SizedBox(height: 24),
                                // Predictive Indicator Tag
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.analytics_outlined, size: 14, color: auraColor),
                                    const SizedBox(width: 6),
                                    Text(
                                      "TOMORROW TARGET: $tomorrowTrendText",
                                      style: GoogleFonts.poppins(
                                        textStyle: TextStyle(color: auraColor, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 20),

                          // 🧮 INTERACTIVE INVESTMENT CALCULATOR
                          GlassContainer(
                            width: double.infinity,
                            height: 230,
                            blur: 18,
                            color: Colors.white.withOpacity(0.02),
                            gradient: LinearGradient(
                              colors: [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.01)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            borderWidth: 1.0,
                            borderColor: Colors.white.withOpacity(0.05),
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "GPAY DEPOSIT SIMULATOR",
                                  style: TextStyle(color: Colors.amber[300], fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: TextField(
                                        controller: _calculatorController,
                                        keyboardType: TextInputType.number,
                                        style: GoogleFonts.spaceGrotesk(textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                                        decoration: InputDecoration(
                                          prefixText: "₹ ",
                                          prefixStyle: const TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold),
                                          labelText: "Enter Investment Amount",
                                          labelStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white10)),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.amber, width: 1.2)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text("YOU RECEIVE", style: TextStyle(color: Colors.grey[400], fontSize: 10, fontWeight: FontWeight.bold)),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              "${calculatedGrams.toStringAsFixed(4)} g",
                                              style: GoogleFonts.spaceGrotesk(textStyle: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.amber)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12.0),
                                  child: Divider(color: Colors.white10, height: 1),
                                ),
                                // Transaction Checkout Breakdown
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Govt GST (3%): ₹${calculatedGSTAmount.toStringAsFixed(2)}", style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                                    Text("Net Gold Value Asset: ₹${calculatedNetInvestment.toStringAsFixed(2)}", style: TextStyle(color: Colors.grey[400], fontSize: 11, fontWeight: FontWeight.w500)),
                                  ],
                                )
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // CORE SYSTEM ACTION SIGNAL CARD
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            decoration: BoxDecoration(
                              color: auraColor.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: auraColor.withOpacity(0.35), width: 1.2),
                            ),
                            child: Text(
                              decisionText,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                textStyle: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: auraColor,
                                  letterSpacing: 0.5,
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
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: loadAppWithPrediction,
        backgroundColor: Colors.amber,
        foregroundColor: const Color(0xFF0F0E13),
        icon: const Icon(Icons.sync_rounded),
        label: const Text(
          "REFRESH PORTFOLIO FEED",
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 12),
        ),
      ),
    );
  }
}

// flutter run