import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';

class RefuseTaskPrompt extends StatelessWidget {
  final bool show;
  final String text;

  const RefuseTaskPrompt({
    super.key,
    required this.show,
    this.text = "Refuse task? Tap for Punishment.",
  });

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();

    return FadeInUp(
      duration: const Duration(milliseconds: 500),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
