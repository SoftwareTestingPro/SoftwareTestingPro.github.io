import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/player.dart';

class SetupController {
  static final SetupController _instance = SetupController._internal();
  factory SetupController() => _instance;
  SetupController._internal();

  Future<List<Player>> loadSavedPlayers() async {
    final prefs = await SharedPreferences.getInstance();
    final String? playersJson = prefs.getString('saved_players');
    if (playersJson != null) {
      final List<dynamic> decoded = json.decode(playersJson);
      return decoded.map((p) => Player.fromJson(p)).toList();
    }
    return [];
  }

  Future<void> savePlayers(List<Player> players) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = json.encode(players.map((p) => p.toJson()).toList());
    await prefs.setString('saved_players', encoded);
  }
}
