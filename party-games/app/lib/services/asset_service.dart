import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/task_data.dart';

class AssetService {
  static final AssetService _instance = AssetService._internal();
  factory AssetService() => _instance;
  AssetService._internal();

  Map<int, TaskData> baseTasks = {};
  List<String> punishments = [];
  bool tasksLoaded = false;

  Future<void> loadTasks() async {
    if (tasksLoaded) return;

    try {
      for (int i = 1; i <= 4; i++) {
        final String jsonString = await rootBundle.loadString('assets/tasks/Base-$i.json');
        final dynamic jsonData = json.decode(jsonString);
        baseTasks[i] = TaskData.fromJson(jsonData);
      }

      final String pString = await rootBundle.loadString('assets/tasks/Punishments.json');
      punishments = List<String>.from(json.decode(pString));

      tasksLoaded = true;
    } catch (e) {
      print("Error loading tasks: $e");
    }
  }
}
