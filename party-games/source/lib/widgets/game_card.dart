import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../models/player.dart';

class GameCard extends StatelessWidget {
  final double width;
  final double height;
  final String content;
  final bool isPunishment;
  final String? label;
  final Gender? gender;

  const GameCard({
    super.key,
    required this.width,
    required this.height,
    required this.content,
    this.isPunishment = false,
    this.label,
    this.gender,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(
            isPunishment
                ? 'assets/images/punishment_card_bg.jpg'
                : gender == Gender.female
                    ? 'assets/images/female_card_bg.jpg'
                    : 'assets/images/male_card_bg.jpg',
          ),
          fit: BoxFit.cover,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, 10),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (label != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: isPunishment ? Colors.white.withOpacity(0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      label!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 35),
                ],
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Text(
                        content.isNotEmpty 
                            ? content[0].toUpperCase() + content.substring(1) 
                            : content,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.3,
                          shadows: const [
                            Shadow(color: Colors.black54, offset: Offset(2, 2), blurRadius: 6)
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GameCardPlaceholder extends StatelessWidget {
  final double width;
  final double height;
  final IconData icon;

  const GameCardPlaceholder({
    super.key,
    required this.width,
    required this.height,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white12),
      ),
      child: Center(
        child: Icon(icon, color: Colors.white.withOpacity(0.05), size: 100),
      ),
    );
  }
}
