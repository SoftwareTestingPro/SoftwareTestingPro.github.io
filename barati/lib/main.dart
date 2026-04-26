import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/profile_screen.dart';
import 'theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase and SharedPreferences in parallel for faster startup
  final results = await Future.wait([
    Supabase.initialize(
      url: 'https://xuddgewdxhlgdklpyleu.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh1ZGRnZXdkeGhsZ2RrbHB5bGV1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY5NTI1NTQsImV4cCI6MjA5MjUyODU1NH0.p0YcHhOd4KRUQRdgduYViLCmYzh3-0hkDZQoJHeRpSU',
    ),
    SharedPreferences.getInstance(),
  ]);

  final prefs = results[1] as SharedPreferences;
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  // Pre-cache fonts and assets if possible (implicit in Flutter, but ensures data is ready)
  print('App Init: isLoggedIn=$isLoggedIn');

  Widget initialScreen = isLoggedIn ? const HomeScreen() : const AuthScreen();

  runApp(MyApp(initialScreen: initialScreen));
}

class MyApp extends StatelessWidget {
  final Widget initialScreen;
  const MyApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Barati - Your Chosen Family',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => initialScreen,
        '/auth': (context) => const AuthScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}
