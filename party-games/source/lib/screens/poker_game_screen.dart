import 'dart:async';
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../main.dart';
import '../controllers/poker_controller.dart';
import '../core/utils.dart';
import '../core/constants.dart';
import '../core/game_mixin.dart';
import '../core/game_layout.dart';
import '../widgets/game_card.dart';
import '../widgets/level_selector.dart';
import '../widgets/game_timer_display.dart';
import '../widgets/refuse_task_prompt.dart';
import 'dart:math' as math;
import 'package:wakelock_plus/wakelock_plus.dart';

class PokerGameScreen extends StatefulWidget {
  const PokerGameScreen({super.key});

  @override
  State<PokerGameScreen> createState() => _PokerGameScreenState();
}

class _PokerGameScreenState extends State<PokerGameScreen> 
    with TickerProviderStateMixin, GameLogicMixin<PokerGameScreen> {
  final PokerController _controller = PokerController();
  String _currentTask = "";
  String _currentPunishment = "";
  bool _isFlipped = false;
  
  late AnimationController _flipController;
  late AnimationController _swipeController;

  Offset _dragOffset = Offset.zero;
  double _dragAngle = 0;
  
  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    WakelockPlus.enable();
    // Start with empty task to show "game load" UI
    _currentTask = "";
  }

  @override
  void dispose() {
    _flipController.dispose();
    _swipeController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  void _nextTask() {
    setState(() {
      _isFlipped = false;
      _flipController.reverse();
      _currentTask = _controller.getNextTask();
      stopTimer();
      secondsLeft = 0; // Clear timer UI immediately
      checkForTimer(_currentTask);
    });
  }

  void _showPunishment() {
    setState(() {
      _currentPunishment = _controller.getRandomPunishment(_controller.lastActivePlayer);
      _isFlipped = true;
      _flipController.forward();
      stopTimer();
      checkForTimer(_currentPunishment);
    });
  }

  void _swipeAway(bool isRight) {
    stopTimer(); // Ensure timer stops on swipe
    final screenWidth = MediaQuery.of(context).size.width;
    final targetX = isRight ? screenWidth * 1.5 : -screenWidth * 1.5;
    _startSwipeAnimation(Offset(targetX, _dragOffset.dy), nextTask: true);
  }

  void _returnToCenter() {
    _startSwipeAnimation(Offset.zero, nextTask: false);
  }

  void _startSwipeAnimation(Offset targetOffset, {required bool nextTask}) {
    _swipeController.stop();
    final startOffset = _dragOffset;
    final startAngle = _dragAngle;
    final targetAngle = nextTask ? (targetOffset.dx > 0 ? 0.4 : -0.4) : 0.0;

    void listener() {
      setState(() {
        _dragOffset = Offset.lerp(startOffset, targetOffset, _swipeController.value)!;
        _dragAngle = lerpDouble(startAngle, targetAngle, _swipeController.value)!;
      });
    }

    _swipeController.reset();
    _swipeController.addListener(listener);
    _swipeController.forward().then((_) {
      _swipeController.removeListener(listener);
      if (nextTask) {
        _nextTask();
        setState(() {
          _dragOffset = Offset.zero;
          _dragAngle = 0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: Text(
          'STRIP POKER',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded),
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false),
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              LevelSelector(
                currentLevel: _controller.currentBase,
                onLevelSelected: (level) {
                  setState(() {
                    _controller.switchBase(level);
                    _currentTask = "";
                    _isFlipped = false;
                    stopTimer();
                  });
                },
              ),

              const SizedBox(height: 15),

              if (_currentTask.isNotEmpty)
                FadeInDown(
                  child: Text(
                    "${_controller.lastActivePlayer.name}'s Turn",
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ),

              const SizedBox(height: 15),

              Expanded(
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cardHeight = GameLayout.getCardHeight(context, constraints);
                      final cardWidth = GameLayout.getCardWidth(cardHeight, constraints);

                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_currentTask.isNotEmpty)
                            GameCardPlaceholder(
                              width: cardWidth,
                              height: cardHeight,
                              icon: Icons.style_rounded,
                            ),
                          
                          if (_currentTask.isEmpty)
                            GestureDetector(
                              onTap: _nextTask,
                              child: ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [
                                    Colors.red,
                                    Colors.orange,
                                    Colors.yellow,
                                    Colors.green,
                                    Colors.blue,
                                    Colors.indigo,
                                    Colors.purple,
                                  ],
                                ).createShader(bounds),
                                child: Text(
                                  'Start',
                                  style: GoogleFonts.outfit(
                                    fontSize: 80,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),

                          // Tinder-style "NEXT" overlay
                          if (_dragOffset.dx.abs() > 20)
                            Positioned(
                              top: 50,
                              left: _dragOffset.dx > 0 ? 30 : null,
                              right: _dragOffset.dx < 0 ? 30 : null,
                              child: Opacity(
                                opacity: (_dragOffset.dx.abs() / 100).clamp(0.0, 1.0),
                                child: Transform.rotate(
                                  angle: _dragOffset.dx > 0 ? -0.2 : 0.2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: _dragOffset.dx > 0 ? Colors.greenAccent : Colors.orangeAccent,
                                        width: 4,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      "NEXT",
                                      style: GoogleFonts.outfit(
                                        color: _dragOffset.dx > 0 ? Colors.greenAccent : Colors.orangeAccent,
                                        fontSize: 40,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 4,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          
                          GestureDetector(
                            onHorizontalDragUpdate: _currentTask.isEmpty ? null : (details) {
                              setState(() {
                                _dragOffset += details.delta;
                                _dragAngle = (_dragOffset.dx / constraints.maxWidth) * 0.2;
                              });
                            },
                            onHorizontalDragEnd: (details) {
                              final threshold = constraints.maxWidth * 0.35;
                              final isLeft = _dragOffset.dx < -threshold || (details.primaryVelocity ?? 0) < -500;
                              final isRight = _dragOffset.dx > threshold || (details.primaryVelocity ?? 0) > 500;
                              
                              if (isLeft) {
                                _swipeAway(false);
                              } else if (isRight) {
                                _swipeAway(true);
                              } else {
                                _returnToCenter();
                              }
                            },
                            onTap: () {
                              if (_currentTask.isEmpty) return;
                              if (_isFlipped) {
                                setState(() {
                                  _isFlipped = false;
                                  _flipController.reverse();
                                  stopTimer();
                                  checkForTimer(_currentTask);
                                });
                              } else {
                                _showPunishment();
                              }
                            },
                            child: _currentTask.isEmpty 
                              ? const SizedBox.shrink()
                              : Transform(
                                  transform: Matrix4.translationValues(_dragOffset.dx, _dragOffset.dy, 0)
                                    ..rotateZ(_dragAngle),
                                  alignment: Alignment.center,
                                  child: AnimatedBuilder(
                                    animation: _flipController,
                                    builder: (context, child) {
                                      final angle = _flipController.value * math.pi;
                                      return Transform(
                                        transform: Matrix4.identity()
                                          ..setEntry(3, 2, 0.001)
                                          ..rotateY(angle),
                                        alignment: Alignment.center,
                                        child: angle < math.pi / 2
                                            ? GameCard(
                                                width: cardWidth,
                                                height: cardHeight,
                                                content: _currentTask,
                                                gender: _controller.lastActivePlayer.gender,
                                              )
                                            : Transform(
                                                transform: Matrix4.identity()..rotateY(math.pi),
                                                alignment: Alignment.center,
                                                child: GameCard(
                                                  width: cardWidth,
                                                  height: cardHeight,
                                                  content: _currentPunishment,
                                                  isPunishment: true,
                                                  label: "PUNISHMENT",
                                                  gender: _controller.lastActivePlayer.gender,
                                                ),
                                              ),
                                      );
                                    },
                                  ),
                                ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 10),

              GameTimerDisplay(
                secondsLeft: secondsLeft,
                isRunning: timerRunning,
                onStart: () => startTimer(() {}),
              ),
              
              const SizedBox(height: 12),

              RefuseTaskPrompt(
                show: !_isFlipped && _currentTask.isNotEmpty,
              ),
              
              const SizedBox(height: 12),
              
              if (_currentTask.isNotEmpty)
                const Text(
                  'Swipe for Next Task • Tap to Flip',
                  style: TextStyle(
                    color: Colors.white70, 
                    fontSize: 13, 
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black26, offset: Offset(0, 1), blurRadius: 2)],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
