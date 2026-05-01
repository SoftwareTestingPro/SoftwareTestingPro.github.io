import '../models/player.dart';
import 'game_controller.dart';

class PokerController extends GameController {
  static final PokerController _instance = PokerController._internal();
  factory PokerController() => _instance;
  PokerController._internal();

  Player get lastActivePlayer {
    return players[(currentPlayerIndex - 1 + players.length) % players.length];
  }
}
