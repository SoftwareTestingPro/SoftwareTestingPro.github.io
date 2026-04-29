import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../core/utils.dart';

mixin GameLogicMixin<T extends StatefulWidget> on State<T> {
  final AudioPlayer audioPlayer = AudioPlayer();
  Timer? timer;
  int secondsLeft = 0;
  bool timerRunning = false;

  void checkForTimer(String text) {
    final duration = GameUtils.parseTimerDuration(text);
    setState(() {
      secondsLeft = duration ?? 0;
    });
  }

  void startTimer(VoidCallback onTick) {
    setState(() => timerRunning = true);
    timer?.cancel();
    playTimerSound();
    
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (secondsLeft > 0) {
        setState(() {
          secondsLeft--;
          playTimerSound();
        });
        if (secondsLeft == 0) {
          stopTimer();
        }
      } else {
        stopTimer();
      }
      onTick();
    });
  }

  void playTimerSound() {
    if (secondsLeft > 8) {
      audioPlayer.play(AssetSource('sounds/tick.mp3'));
    } else if (secondsLeft > 3) {
      audioPlayer.play(AssetSource('sounds/warning.mp3'));
    } else {
      audioPlayer.play(AssetSource('sounds/end.mp3'));
    }
  }

  void stopTimer() {
    timer?.cancel();
    setState(() => timerRunning = false);
  }

  @override
  void dispose() {
    timer?.cancel();
    audioPlayer.dispose();
    super.dispose();
  }
}
