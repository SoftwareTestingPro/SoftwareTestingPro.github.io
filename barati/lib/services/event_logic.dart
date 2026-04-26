import '../models/models.dart';

class EventLogic {
  /// Checks if an event is in the past.
  static bool isEventPast(BaratiEvent event) {
    return event.date.isBefore(DateTime.now());
  }

  /// Finds the application where the user was approved for an event.
  static RoleApplication? getApprovedApplication(List<RoleApplication> applications) {
    try {
      return applications.firstWhere((a) => a.isApproved);
    } catch (_) {
      return null;
    }
  }

  /// Filters events for the host dashboard.
  static List<BaratiEvent> filterHostEvents(List<BaratiEvent> allEvents, String hostId, {required bool isPast}) {
    final now = DateTime.now();
    return allEvents.where((e) {
      final matchesHost = e.hostId == hostId;
      final matchesTime = isPast ? e.date.isBefore(now) : e.date.isAfter(now);
      return matchesHost && matchesTime;
    }).toList();
  }

  /// Formats a date to DD/MM/YYYY.
  static String formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
