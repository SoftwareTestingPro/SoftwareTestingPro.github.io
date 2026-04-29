import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../main.dart';
import '../controllers/spinner_controller.dart';
import 'dart:math' as math;
import 'package:wakelock_plus/wakelock_plus.dart';

class SpinnerGameScreen extends StatefulWidget {
  const SpinnerGameScreen({super.key});

  @override
  State<SpinnerGameScreen> createState() => _SpinnerGameScreenState();
}

class _SpinnerGameScreenState extends State<SpinnerGameScreen> with SingleTickerProviderStateMixin {
  final SpinnerController _controller = SpinnerController();
  late AnimationController _spinController;
  double _rotationAngle = 0;
  bool _isSpinning = false;
  String _currentTask = "";
  bool _showTaskModal = false;

  final Map<int, String> baseIcons = {1: "🥳", 2: "🤓", 3: "🫦", 4: "👙"};

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    _spinController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  void _spinBottle() {
    if (_isSpinning) return;

    setState(() {
      _isSpinning = true;
      _showTaskModal = false;
    });

    final double randomRotation = math.pi * 10 + math.Random().nextDouble() * math.pi * 10;
    final double targetAngle = _rotationAngle + randomRotation;

    final animation = CurvedAnimation(
      parent: _spinController,
      curve: Curves.elasticOut,
    );

    _spinController.reset();
    
    // We'll use a Tween to animate the rotation
    final rotationAnimation = Tween<double>(begin: _rotationAngle, end: targetAngle).animate(animation);

    rotationAnimation.addListener(() {
      setState(() {
        _rotationAngle = rotationAnimation.value;
      });
    });

    _spinController.forward().then((_) {
      setState(() {
        _isSpinning = false;
        _rotationAngle = _rotationAngle % (2 * math.pi);
        _showTask();
      });
    });
  }

  void _showTask() {
    setState(() {
      _currentTask = _controller.getNextTaskForBottle();
      _showTaskModal = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Spin the Bottle'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 40),
                const Text(
                  'Spin the Bottle',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                
                // Bottle
                Center(
                  child: Transform.rotate(
                    angle: _rotationAngle,
                    child: _BottleWidget(),
                  ),
                ),
                
                const Spacer(),
                
                Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: ElevatedButton(
                    onPressed: _isSpinning ? null : _spinBottle,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 60),
                    ),
                    child: Text(_isSpinning ? 'Spinning...' : 'Spin the Bottle'),
                  ),
                ),
              ],
            ),
          ),
          
          if (_showTaskModal)
            _TaskModal(
              task: _currentTask,
              base: _controller.currentBase,
              baseIcon: baseIcons[_controller.currentBase]!,
              onClose: () => setState(() => _showTaskModal = false),
              onPunish: () {
                 setState(() {
                   _currentTask = _controller.getPunishmentForBottle();
                 });
              },
              onBaseChange: (base) {
                setState(() {
                  _controller.currentBase = base;
                  _showTask();
                });
              },
            ),
        ],
      ),
    );
  }
}

class _BottleWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Bottle Body
          Container(
            width: 40,
            height: 120,
            margin: const EdgeInsets.only(top: 40),
            decoration: BoxDecoration(
              color: const Color(0xFF2D5A27),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(5, 5))],
            ),
          ),
          // Bottle Neck
          Positioned(
            top: 10,
            child: Container(
              width: 15,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF2D5A27),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          // Cap
          Positioned(
            top: 0,
            child: Container(
              width: 18,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFFB8860B),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskModal extends StatelessWidget {
  final String task;
  final int base;
  final String baseIcon;
  final VoidCallback onClose;
  final VoidCallback onPunish;
  final Function(int) onBaseChange;

  const _TaskModal({
    required this.task,
    required this.base,
    required this.baseIcon,
    required this.onClose,
    required this.onPunish,
    required this.onBaseChange,
  });

  @override
  Widget build(BuildContext context) {
    return FadeIn(
      child: Container(
        color: Colors.black87,
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(baseIcon, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Text('Level $base', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  task,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onClose,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B6B)),
                        child: const Text('Done'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onPunish,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4757)),
                        child: const Text('Punish'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [1, 2, 3, 4].map((b) {
                      if (b == base) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ActionChip(
                          backgroundColor: Colors.white24,
                          label: Text('Lvl $b'),
                          onPressed: () => onBaseChange(b),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
