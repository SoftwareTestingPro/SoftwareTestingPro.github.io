import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../main.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  FadeInDown(
                    child: const Text(
                      'Games Hub',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black26, offset: Offset(0, 4), blurRadius: 8)],
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  FadeInUp(
                    delay: const Duration(milliseconds: 200),
                    child: _GameLink(
                      title: 'Strip Poker',
                      icon: '🃏',
                      onTap: () => Navigator.pushNamed(context, '/player_setup', arguments: '/poker'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeInUp(
                    delay: const Duration(milliseconds: 400),
                    child: _GameLink(
                      title: 'Bottle Spinner',
                      icon: '🍾',
                      onTap: () => Navigator.pushNamed(context, '/player_setup', arguments: '/spinner'),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GameLink extends StatelessWidget {
  final String title;
  final String icon;
  final VoidCallback onTap;

  const _GameLink({required this.title, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF222222),
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, color: Color(0xFF222222)),
          ],
        ),
      ),
    );
  }
}
