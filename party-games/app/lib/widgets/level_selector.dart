import 'package:flutter/material.dart';
import '../core/constants.dart';

class LevelSelector extends StatelessWidget {
  final int currentLevel;
  final Function(int) onLevelSelected;

  const LevelSelector({
    super.key,
    required this.currentLevel,
    required this.onLevelSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [1, 2, 3, 4].map((b) {
          final isActive = b == currentLevel;
          return GestureDetector(
            onTap: () => onLevelSelected(b),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? GameConstants.accentColor : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Text(GameConstants.baseIcons[b]!, style: const TextStyle(fontSize: 18)),
                  if (isActive)
                    Padding(
                      padding: const EdgeInsets.only(left: 6.0),
                      child: Text(
                        'L$b',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
