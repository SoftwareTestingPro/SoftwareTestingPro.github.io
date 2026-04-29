import 'dart:async';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../controllers/poker_controller.dart';
import '../core/utils.dart';
import 'dart:math' as math;
import 'package:wakelock_plus/wakelock_plus.dart';

class PokerGameScreen extends StatefulWidget {
  const PokerGameScreen({super.key});

  @override
  State<PokerGameScreen> createState() => _PokerGameScreenState();
}

class _PokerGameScreenState extends State<PokerGameScreen> with SingleTickerProviderStateMixin {
  final PokerController _controller = PokerController();
  String _currentTask = "";
  String _currentPunishment = "";
  bool _isFlipped = false;
  late AnimationController _flipController;
  
  Timer? _timer;
  int _secondsLeft = 0;
  bool _timerRunning = false;

  final Map<int, String> baseIcons = {1: "🥳", 2: "🤓", 3: "🫦", 4: "👙"};

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    WakelockPlus.enable();
    _nextTask();
  }

  @override
  void dispose() {
    _flipController.dispose();
    _timer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  void _nextTask() {
    setState(() {
      _isFlipped = false;
      _flipController.reverse();
      _currentTask = _controller.getNextTask();
      _stopTimer();
      _checkForTimer(_currentTask);
    });
  }

  void _showPunishment() {
    final player = _controller.lastActivePlayer;
    setState(() {
      _currentPunishment = _controller.getRandomPunishment(player);
      _isFlipped = true;
      _flipController.forward();
      _stopTimer();
      _checkForTimer(_currentPunishment);
    });
  }

  void _checkForTimer(String text) {
    final duration = GameUtils.parseTimerDuration(text);
    setState(() {
      _secondsLeft = duration ?? 0;
    });
  }

  void _startTimer() {
    setState(() => _timerRunning = true);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          _timer?.cancel();
          _timerRunning = false;
        }
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() => _timerRunning = false);
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
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _nextTask,
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              // Level Selector (Top Row)
              Container(
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
                    final isActive = b == _controller.currentBase;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _controller.switchBase(b);
                          _nextTask();
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFFFF6B6B) : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Text(baseIcons[b]!, style: const TextStyle(fontSize: 18)),
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
              ),

              const SizedBox(height: 10),

              // Active Player Indicator
              if (_controller.players.isNotEmpty)
                FadeInDown(
                  child: Text(
                    "${_controller.players[(_controller.currentPlayerIndex - 1 + _controller.players.length) % _controller.players.length].name}'s Turn",
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ),

              const SizedBox(height: 10),

              // 3D Card Area
              Expanded(
                child: GestureDetector(
                  onHorizontalDragEnd: (details) {
                    if (details.primaryVelocity != null && details.primaryVelocity!.abs() > 300) {
                      _nextTask();
                    }
                  },
                  onTap: () {
                    if (!_isFlipped) _showPunishment();
                  },
                  child: Center(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Dynamically size card based on available space
                        final cardHeight = constraints.maxHeight.clamp(200.0, 420.0);
                        final cardWidth = (cardHeight * 0.76).clamp(150.0, 320.0);
                        
                        return AnimatedBuilder(
                          animation: _flipController,
                          builder: (context, child) {
                            final angle = _flipController.value * math.pi;
                            return Transform(
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.001)
                                ..rotateY(angle),
                              alignment: Alignment.center,
                              child: angle < math.pi / 2
                                  ? _buildCardFront(cardWidth, cardHeight)
                                  : Transform(
                                      transform: Matrix4.identity()..rotateY(math.pi),
                                      alignment: Alignment.center,
                                      child: _buildCardBack(cardWidth, cardHeight),
                                    ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Timer & Actions Area
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_secondsLeft > 0)
                    FadeInUp(
                      child: _timerRunning
                          ? _buildGlowTimer()
                          : _buildStartTimerButton(),
                    ),
                  
                  const SizedBox(height: 12),
                  
                  if (!_isFlipped)
                    FadeInUp(
                      delay: const Duration(milliseconds: 200),
                      child: _buildPunishButton(),
                    ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              const Text(
                'Swipe Right for Next Task',
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlowTimer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00F2FE).withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 2,
          )
        ],
      ),
      child: Text(
        _secondsLeft == 0 ? "TIME'S UP!" : '⏱️ ${_secondsLeft}s',
        style: GoogleFonts.outfit(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildStartTimerButton() {
    return ElevatedButton.icon(
      onPressed: _startTimer,
      icon: const Icon(Icons.timer_outlined, size: 20),
      label: Text('START ${_secondsLeft}s TIMER'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.1),
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white24),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPunishButton() {
    return GestureDetector(
      onTap: _showPunishment,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF4757), Color(0xFFFF6B6B)],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF4757).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_fire_department, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              "I CAN'T, PUNISH ME",
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardFront(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6A11CB).withOpacity(0.4),
            const Color(0xFF2575FC).withOpacity(0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6A11CB).withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 15),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            // Glass effect shine
            Positioned(
              top: -50,
              left: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.psychology_alt_rounded, color: Colors.white30, size: 40),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Text(
                          _currentTask,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.3,
                            shadows: [
                              const Shadow(color: Colors.black45, offset: Offset(2, 2), blurRadius: 4)
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'TAP TO FLIP',
                    style: TextStyle(color: Colors.white24, letterSpacing: 2, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardBack(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFF0844).withOpacity(0.5),
            const Color(0xFFFFB199).withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFFF0844).withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF0844).withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(0, 15),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4757),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'PUNISHMENT',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Text(
                          _currentPunishment,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.3,
                            shadows: [
                              const Shadow(color: Colors.black45, offset: Offset(2, 2), blurRadius: 4)
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'SWIPE FOR NEXT',
                    style: TextStyle(color: Colors.white24, letterSpacing: 2, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
