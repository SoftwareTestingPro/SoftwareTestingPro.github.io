import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/profile_screen.dart';
import 'theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://xuddgewdxhlgdklpyleu.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh1ZGRnZXdkeGhsZ2RrbHB5bGV1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY5NTI1NTQsImV4cCI6MjA5MjUyODU1NH0.p0YcHhOd4KRUQRdgduYViLCmYzh3-0hkDZQoJHeRpSU',
  );

  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  final bool hasProfile = prefs.getBool('hasProfile') ?? false;

  print('App Init: isLoggedIn=$isLoggedIn, hasProfile=$hasProfile');

  Widget initialScreen;
  if (!isLoggedIn) {
    initialScreen = const AuthScreen();
  } else if (!hasProfile) {
    initialScreen = const ProfileScreen();
  } else {
    initialScreen = const HomeScreen();
  }

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
