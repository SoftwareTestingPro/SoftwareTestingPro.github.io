class TaskData {
  final List<String> common;
  final List<String> male;
  final List<String> female;

  TaskData({
    required this.common,
    required this.male,
    required this.female,
  });

  factory TaskData.fromJson(Map<String, dynamic> json) {
    return TaskData(
      common: List<String>.from(json['common'] ?? []),
      male: List<String>.from(json['male'] ?? []),
      female: List<String>.from(json['female'] ?? []),
    );
  }
}
