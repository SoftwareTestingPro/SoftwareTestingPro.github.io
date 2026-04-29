import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../core/constants.dart';

class GameTimerDisplay extends StatelessWidget {
  final int secondsLeft;
  final bool isRunning;
  final VoidCallback onStart;

  const GameTimerDisplay({
    super.key,
    required this.secondsLeft,
    required this.isRunning,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    if (secondsLeft <= 0) return const SizedBox.shrink();

    return FadeInUp(
      child: isRunning ? _buildGlowTimer() : _buildStartTimerButton(),
    );
  }

  Widget _buildGlowTimer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white24),
        boxShadow: [
          BoxShadow(
            color: GameConstants.timerGlowColor.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 2,
          )
        ],
      ),
      child: Text(
        secondsLeft == 0 ? "TIME'S UP!" : '⏱️ ${secondsLeft}s',
        style: GoogleFonts.outfit(
          fontSize: 36,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildStartTimerButton() {
    return ElevatedButton.icon(
      onPressed: onStart,
      icon: const Icon(Icons.timer_outlined, size: 22),
      label: Text('START ${secondsLeft}s TIMER'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.1),
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white24),
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    );
  }
}
