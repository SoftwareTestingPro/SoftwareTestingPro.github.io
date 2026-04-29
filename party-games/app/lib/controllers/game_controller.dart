import 'dart:math';
import '../models/player.dart';
import '../models/task_data.dart';
import '../services/asset_service.dart';

abstract class GameController {
  final AssetService assetService = AssetService();
  List<Player> players = [];
  
  int currentPlayerIndex = 0;
  int maleIndex = 0;
  int femaleIndex = 0;
  int currentBase = 1;

  void init(List<Player> players) {
    this.players = players;
    currentPlayerIndex = 0;
    maleIndex = 0;
    femaleIndex = 0;
    currentBase = 1;
  }

  String getNextTask() {
    if (players.isEmpty) return "No players added!";
    
    final data = assetService.baseTasks[currentBase];
    if (data == null) return "Level tasks not loaded!";

    final currentPlayer = players[currentPlayerIndex];
    
    List<String> pool = [...data.common];
    if (currentPlayer.gender == Gender.male) {
      pool.addAll(data.male);
    } else {
      pool.addAll(data.female);
    }

    if (pool.isEmpty) return "No tasks available for this level!";

    String task = pool[Random().nextInt(pool.length)];
    String processedTask = processTaskPlaceholders(task, currentPlayer);

    currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
    return processedTask;
  }

  String getRandomPunishment(Player player) {
    final pool = assetService.basePunishments[currentBase] ?? [];
    if (pool.isEmpty) return "No punishments available!";
    String p = pool[Random().nextInt(pool.length)];
    return p.replaceAll('{p1}', player.name);
  }

  String processTaskPlaceholders(String task, Player currentPlayer) {
    String result = task;
    
    if (result.contains('{p1}')) {
      result = result.replaceAll('{p1}', currentPlayer.name);
    } else {
      result = "${currentPlayer.name}: $result";
    }

    if (result.contains('{p2}')) {
      Player? partner;
      if (currentPlayer.gender == Gender.male) {
        final females = players.where((p) => p.gender == Gender.female).toList();
        if (females.isNotEmpty) {
          partner = females[femaleIndex % females.length];
          femaleIndex++;
        }
      } else {
        final males = players.where((p) => p.gender == Gender.male).toList();
        if (males.isNotEmpty) {
          partner = males[maleIndex % males.length];
          maleIndex++;
        }
      }

      if (partner == null && players.length > 1) {
        final others = players.where((p) => p != currentPlayer).toList();
        partner = others[Random().nextInt(others.length)];
      }

      if (partner != null) {
        result = result.replaceAll('{p2}', partner.name);
      } else {
        result = result.replaceAll('{p2}', "someone");
      }
    }

    return result;
  }
}
