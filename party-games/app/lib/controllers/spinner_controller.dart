import 'dart:math';
import '../models/player.dart';
import 'game_controller.dart';

class SpinnerController extends GameController {
  static final SpinnerController _instance = SpinnerController._internal();
  factory SpinnerController() => _instance;
  SpinnerController._internal();

  Player? _lastSelectedPlayer;
  Player? get lastSelectedPlayer => _lastSelectedPlayer;

  void pickRandomPlayer() {
    _lastSelectedPlayer = players[Random().nextInt(players.length)];
  }

  @override
  String getNextTask() {
    if (_lastSelectedPlayer == null) pickRandomPlayer();
    final p1 = _lastSelectedPlayer!;
    
    final taskData = assetService.baseTasks[currentBase];
    if (taskData == null) return "No tasks loaded";

    List<String> pool = [...taskData.common];
    if (p1.gender == Gender.male) {
      pool.addAll(taskData.male);
    } else {
      pool.addAll(taskData.female);
    }

    if (pool.isEmpty) return "No tasks available for this level!";
    String task = pool[Random().nextInt(pool.length)];
    
    // For Bottle Spinner, we remove p1 and p2 placeholders as the bottle 
    // indicates who does what to whom.
    task = task.replaceAll('{p1}', '').trim();
    task = task.replaceAll('{p2}', 'someone');
    
    // Clean up double spaces or leading commas if any
    if (task.startsWith(',')) task = task.substring(1).trim();
    
    return task;
  }

  @override
  String getRandomPunishment(Player player) {
    final pool = assetService.basePunishments[currentBase] ?? [];
    if (pool.isEmpty) return "No punishments available!";
    String p = pool[Random().nextInt(pool.length)];
    
    // Replace p1 with "You" and others with "someone" if applicable
    p = p.replaceAll('{p1}', 'You');
    p = p.replaceAll(player.name, 'You');
    return p;
  }
}
