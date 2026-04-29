import '../models/player.dart';
import 'game_controller.dart';

class SpinnerController extends GameController {
  static final SpinnerController _instance = SpinnerController._internal();
  factory SpinnerController() => _instance;
  SpinnerController._internal();

  String getNextTaskForBottle() {
    String task = getNextTask();
    final player = players[(currentPlayerIndex - 1 + players.length) % players.length];
    
    // Bottle spinner specific: replace name with "You"
    task = task.replaceAll(player.name + ':', 'You:');
    task = task.replaceAll(player.name, 'You');
    return task;
  }

  String getPunishmentForBottle() {
    final player = players[(currentPlayerIndex - 1 + players.length) % players.length];
    String p = getRandomPunishment(player);
    return p.replaceAll(player.name, 'You');
  }
}
