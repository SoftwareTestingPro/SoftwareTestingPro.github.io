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
      if (e.hostId != hostId) return false;
      
      if (isPast) {
        return e.date.isBefore(now);
      } else {
        // If it's today or in the future, it's upcoming
        return e.date.isAfter(now) || 
               (e.date.year == now.year && e.date.month == now.month && e.date.day == now.day && e.date.isAfter(now.subtract(const Duration(hours: 1)))); // Buffer of 1 hour for ongoing events
      }
    }).toList();
  }

  /// Formats a date to DD/MM/YYYY.
  static String formatDate(DateTime date) {
    final d = date.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  /// Formats a time to HH:MM AM/PM.
  static String formatTime(DateTime date) {
    final d = date.toLocal();
    final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final period = d.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} $period';
  }

  /// Formats both date and time.
  static String formatDateTime(DateTime date) {
    return '${formatDate(date)} ${formatTime(date)}';
  }

  /// Gets a default image URL based on event type.
  static String getDefaultImageUrl(EventType type) {
    return 'assets/images/${type.name}.jpg';
  }
}
