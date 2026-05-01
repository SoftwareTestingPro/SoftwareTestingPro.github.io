class GameUtils {
  static int? parseTimerDuration(String text) {
    final RegExp timeRegex = RegExp(r'(\d+)\s*-?\s*(Second|Minute)s?', caseSensitive: false);
    final match = timeRegex.firstMatch(text);

    if (match != null) {
      int duration = int.parse(match.group(1)!);
      String unit = match.group(2)!.toLowerCase();

      if (unit.startsWith('minute')) {
        duration *= 60;
      }
      return duration;
    }
    return null;
  }
}
