import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';
import 'screens/player_setup_screen.dart';
import 'screens/poker_game_screen.dart';
import 'screens/spinner_game_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PartyGamesApp());
}

class PartyGamesApp extends StatelessWidget {
  const PartyGamesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Game Hub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: Colors.transparent,
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF6B6B),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/player_setup': (context) => const PlayerSetupScreen(),
        '/poker': (context) => const PokerGameScreen(),
        '/spinner': (context) => const SpinnerGameScreen(),
      },
    );
  }
}

class GradientScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;

  const GradientScaffold({super.key, required this.body, this.appBar});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
        ),
      ),
      child: Scaffold(
        appBar: appBar,
        body: body,
      ),
    );
  }
}
