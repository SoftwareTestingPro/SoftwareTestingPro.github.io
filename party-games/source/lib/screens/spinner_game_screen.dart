import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../main.dart';
import '../controllers/spinner_controller.dart';
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

class SpinnerGameScreen extends StatefulWidget {
  const SpinnerGameScreen({super.key});

  @override
  State<SpinnerGameScreen> createState() => _SpinnerGameScreenState();
}

class _SpinnerGameScreenState extends State<SpinnerGameScreen> 
    with TickerProviderStateMixin, GameLogicMixin<SpinnerGameScreen> {
  final SpinnerController _controller = SpinnerController();
  String _currentTask = "";
  String _currentPunishment = "";
  bool _isFlipped = false;
  late AnimationController _flipController;
  late AnimationController _spinController;

  bool _showBottle = true; 
  bool _isSpinning = false;
  double _bottleRotation = 0;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    _flipController.dispose();
    _spinController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  void _nextTask() {
    setState(() {
      _isFlipped = false;
      _flipController.reverse();
      _currentTask = _controller.getNextTask();
      stopTimer();
      checkForTimer(_currentTask);
    });
  }

  void _spinBottle() {
    if (_isSpinning) return;
    
    setState(() {
      _isSpinning = true;
      _showBottle = true;
      _currentTask = ""; 
      stopTimer();
      secondsLeft = 0; // Clear timer UI immediately
      playSpinSound();
    });

    final double randomAngle = math.pi * 2 * (5 + math.Random().nextDouble() * 5);
    final double startAngle = _bottleRotation;
    
    _spinController.reset();
    final Animation<double> animation = CurvedAnimation(
      parent: _spinController,
      curve: Curves.easeOutQuart,
    );

    void listener() {
      setState(() {
        _bottleRotation = lerpDouble(startAngle, startAngle + randomAngle, animation.value)!;
      });
    }

    _spinController.addListener(listener);
    _spinController.forward().then((_) {
      _spinController.removeListener(listener);
      stopSpinSound();
      _controller.pickRandomPlayer();
      _nextTask(); 
      
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _showBottle = false;
            _isSpinning = false;
          });
        }
      });
    });
  }

  void _showPunishment() {
    if (_currentTask.isEmpty) return;
    final player = _controller.lastSelectedPlayer ?? _controller.players[0];
    setState(() {
      _currentPunishment = _controller.getRandomPunishment(player);
      _isFlipped = true;
      _flipController.forward();
      stopTimer();
      checkForTimer(_currentPunishment);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: Text(
          'BOTTLE SPINNER',
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
                    _showBottle = true;
                    _isSpinning = false;
                    stopTimer();
                  });
                },
              ),

              const SizedBox(height: 15),

              FadeInDown(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    _isSpinning 
                      ? "Spinning..."
                      : _currentTask.isEmpty 
                        ? "Spin the bottle to start"
                        : "The person facing the bottle must perform the task.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
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
                          if (!_showBottle) ...[
                            GameCardPlaceholder(
                              width: cardWidth,
                              height: cardHeight,
                              icon: Icons.star_rounded,
                            ),
                            
                            GestureDetector(
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
                                            gender: _controller.lastSelectedPlayer?.gender,
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
                                              gender: _controller.lastSelectedPlayer?.gender,
                                            ),
                                          ),
                                  );
                                },
                              ),
                            ),
                          ],

                          if (_showBottle)
                            Center(
                              child: GestureDetector(
                                onTap: _spinBottle,
                                child: Transform.rotate(
                                  angle: _bottleRotation,
                                  child: PremiumBottle(height: cardHeight * 0.85),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 15),

              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GameTimerDisplay(
                    secondsLeft: secondsLeft,
                    isRunning: timerRunning,
                    onStart: () => startTimer(() {}),
                  ),
                  
                  const SizedBox(height: 15),
                  
                  if (!_isSpinning)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _spinBottle,
                              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                              label: const Text('SPIN BOTTLE'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4FACFE),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 15),

                  RefuseTaskPrompt(
                    show: !_isFlipped && !_showBottle && _currentTask.isNotEmpty,
                  ),
                ],
              ),
              
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class PremiumBottle extends StatelessWidget {
  final double height;
  const PremiumBottle({super.key, required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: height * 0.3,
      child: CustomPaint(
        painter: _BottlePainter(),
      ),
    );
  }
}

class _BottlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bodyWidth = size.width * 0.75;
    final bodyHeight = size.height * 0.65;
    final neckWidth = size.width * 0.22;
    final capWidth = neckWidth * 1.1;

    final bottlePath = Path();
    
    bottlePath.moveTo(size.width * 0.5 - bodyWidth * 0.45, size.height * 0.95);
    bottlePath.lineTo(size.width * 0.5 + bodyWidth * 0.45, size.height * 0.95);
    
    bottlePath.quadraticBezierTo(
      size.width * 0.5 + bodyWidth * 0.5, size.height * 0.7,
      size.width * 0.5 + bodyWidth * 0.5, size.height * 0.5
    );
    
    bottlePath.cubicTo(
      size.width * 0.5 + bodyWidth * 0.5, size.height * 0.35,
      size.width * 0.5 + neckWidth * 0.6, size.height * 0.3,
      size.width * 0.5 + neckWidth * 0.5, size.height * 0.2
    );
    
    bottlePath.lineTo(size.width * 0.5 + neckWidth * 0.5, size.height * 0.08);
    bottlePath.lineTo(size.width * 0.5 - neckWidth * 0.5, size.height * 0.08);
    bottlePath.lineTo(size.width * 0.5 - neckWidth * 0.5, size.height * 0.2);
    
    bottlePath.cubicTo(
      size.width * 0.5 - neckWidth * 0.6, size.height * 0.3,
      size.width * 0.5 - bodyWidth * 0.5, size.height * 0.35,
      size.width * 0.5 - bodyWidth * 0.5, size.height * 0.5
    );
    
    bottlePath.quadraticBezierTo(
      size.width * 0.5 - bodyWidth * 0.5, size.height * 0.7,
      size.width * 0.5 - bodyWidth * 0.45, size.height * 0.95
    );
    bottlePath.close();

    canvas.drawShadow(bottlePath, Colors.black.withOpacity(0.5), 15, true);

    final glassGradient = LinearGradient(
      colors: [
        const Color(0xFF062106),
        const Color(0xFF0F4D0F),
        const Color(0xFF1E821E),
        const Color(0xFF0F4D0F),
        const Color(0xFF062106),
      ],
      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    final glassPaint = Paint()
      ..shader = glassGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(bottlePath, glassPaint);

    final refractionPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withOpacity(0.15),
          Colors.transparent,
        ],
        center: const Alignment(-0.2, -0.3),
        radius: 0.8,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(bottlePath, refractionPaint);

    final highlightPath1 = Path()
      ..moveTo(size.width * 0.4, size.height * 0.9)
      ..lineTo(size.width * 0.42, size.height * 0.4)
      ..quadraticBezierTo(size.width * 0.43, size.height * 0.3, size.width * 0.48, size.height * 0.25)
      ..lineTo(size.width * 0.48, size.height * 0.1);
    
    canvas.drawPath(
      highlightPath1,
      Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2)
    );

    final labelRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.65),
        width: bodyWidth * 0.85,
        height: bodyHeight * 0.25,
      ),
      const Radius.circular(8),
    );
    
    canvas.drawRRect(
      labelRRect,
      Paint()..color = Colors.white.withOpacity(0.8)
    );
    
    canvas.drawRRect(
      labelRRect,
      Paint()
        ..color = const Color(0xFFC5A059)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
    );

    final capRect = Rect.fromLTWH(
      size.width * 0.5 - capWidth * 0.5,
      size.height * 0.03,
      capWidth,
      size.height * 0.06
    );
    
    final capGradient = LinearGradient(
      colors: [
        const Color(0xFF8E6E26),
        const Color(0xFFD4AF37),
        const Color(0xFFFFD700),
        const Color(0xFFD4AF37),
        const Color(0xFF8E6E26),
      ],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(capRect, const Radius.circular(4)),
      Paint()..shader = capGradient.createShader(capRect)
    );
    
    final ridgePaint = Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (int i = 1; i < 5; i++) {
      double x = capRect.left + (capRect.width / 5) * i;
      canvas.drawLine(Offset(x, capRect.top), Offset(x, capRect.bottom), ridgePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
