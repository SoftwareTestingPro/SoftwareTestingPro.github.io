import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../main.dart';
import '../models/player.dart';
import '../controllers/setup_controller.dart';
import '../controllers/poker_controller.dart';
import '../controllers/spinner_controller.dart';
import '../services/asset_service.dart';

class PlayerSetupScreen extends StatefulWidget {
  const PlayerSetupScreen({super.key});

  @override
  State<PlayerSetupScreen> createState() => _PlayerSetupScreenState();
}

class _PlayerSetupScreenState extends State<PlayerSetupScreen> {
  final List<TextEditingController> _nameControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  final List<Gender?> _genders = [null, null];
  final SetupController _setupController = SetupController();
  final AssetService _assetService = AssetService();

  @override
  void initState() {
    super.initState();
    _loadSavedPlayers();
  }

  Future<void> _loadSavedPlayers() async {
    final players = await _setupController.loadSavedPlayers();
    if (players.isNotEmpty) {
      setState(() {
        _nameControllers.clear();
        _genders.clear();
        for (var player in players) {
          _nameControllers.add(TextEditingController(text: player.name));
          _genders.add(player.gender);
        }
      });
    }
  }

  void _addPlayer() {
    setState(() {
      _nameControllers.add(TextEditingController());
      _genders.add(null);
    });
  }

  void _removePlayer(int index) {
    if (_nameControllers.length <= 2) return;
    setState(() {
      _nameControllers[index].dispose();
      _nameControllers.removeAt(index);
      _genders.removeAt(index);
    });
  }

  void _startGame() async {
    List<Player> players = [];
    for (int i = 0; i < _nameControllers.length; i++) {
      String name = _nameControllers[i].text.trim();
      Gender? gender = _genders[i];

      if (name.isNotEmpty) {
        if (name.length < 3) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Name "$name" must be at least 3 characters.')),
          );
          return;
        }
        if (gender == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please select gender for $name.')),
          );
          return;
        }
        players.add(Player(name: name, gender: gender));
      }
    }

    if (players.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least 2 players.')),
      );
      return;
    }

    int maleCount = players.where((p) => p.gender == Gender.male).length;
    int femaleCount = players.where((p) => p.gender == Gender.female).length;

    if (maleCount < 1 || femaleCount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least 1 male and 1 female player required.')),
      );
      return;
    }

    await _setupController.savePlayers(players);
    await _assetService.loadTasks();

    if (!mounted) return;
    final String nextRoute = ModalRoute.of(context)!.settings.arguments as String;

    // Initialize the specific controller
    if (nextRoute == '/poker') {
      PokerController().init(players);
    } else {
      SpinnerController().init(players);
    }

    Navigator.pushNamed(context, nextRoute);
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Player Setup'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _nameControllers.length,
                itemBuilder: (context, index) {
                  return FadeInRight(
                    delay: Duration(milliseconds: index * 100),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: _PlayerRow(
                        nameController: _nameControllers[index],
                        selectedGender: _genders[index],
                        onGenderSelected: (gender) {
                          setState(() => _genders[index] = gender);
                        },
                        onRemove: () => _removePlayer(index),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _addPlayer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.3),
                      ),
                      child: const Text('Add Player'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _startGame,
                      child: const Text('Start Game'),
                    ),
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

class _PlayerRow extends StatelessWidget {
  final TextEditingController nameController;
  final Gender? selectedGender;
  final Function(Gender) onGenderSelected;
  final VoidCallback onRemove;

  const _PlayerRow({
    required this.nameController,
    required this.selectedGender,
    required this.onGenderSelected,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: TextField(
            controller: nameController,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              hintText: 'First Name',
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: Colors.white.withOpacity(0.9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _GenderButton(
          icon: '♂',
          isSelected: selectedGender == Gender.male,
          onTap: () => onGenderSelected(Gender.male),
          selectedColor: const Color(0xFF4FACFE),
        ),
        const SizedBox(width: 4),
        _GenderButton(
          icon: '♀',
          isSelected: selectedGender == Gender.female,
          onTap: () => onGenderSelected(Gender.female),
          selectedColor: const Color(0xFFFF69B4),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onRemove,
          icon: const Icon(Icons.close, color: Colors.white70),
        ),
      ],
    );
  }
}

class _GenderButton extends StatelessWidget {
  final String icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color selectedColor;

  const _GenderButton({
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          icon,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}
