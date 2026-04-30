import '../models/models.dart';
import 'dart:convert';

class ReputationLogic {
  /// Calculates the average rating a user received as a Barati (Guest).
  /// This is based on [hostRating] fields in applications.
  static double? calculateGuestRating(String userId, List<RoleApplication> allApplications) {
    final guestApps = allApplications
        .where((a) => a.applicantId == userId && a.hostRating != null)
        .toList();
    
    if (guestApps.isEmpty) return null;

    double total = 0;
    for (var app in guestApps) {
      total += app.hostRating!;
    }
    return total / guestApps.length;
  }

  /// Calculates the average rating a host received from their guests.
  /// This is based on [userRating] fields in applications to their events.
  static double? calculateHostRating(String hostId, List<RoleApplication> allApplications, List<BaratiEvent> allEvents) {
    final hostedEventIds = allEvents
        .where((e) => e.hostId == hostId)
        .map((e) => e.id)
        .toSet();
    
    final appsToHostedEvents = allApplications
        .where((a) => hostedEventIds.contains(a.eventId) && a.userRating != null)
        .toList();
    
    if (appsToHostedEvents.isEmpty) return null;

    double total = 0;
    for (var app in appsToHostedEvents) {
      total += app.userRating!;
    }
    return total / appsToHostedEvents.length;
  }

  /// Calculates the average rating for a specific event.
  static double? calculateEventRating(String eventId, List<RoleApplication> allApplications) {
    final eventApps = allApplications
        .where((a) => a.eventId == eventId && a.userRating != null)
        .toList();
    
    if (eventApps.isEmpty) return null;

    double total = 0;
    for (var app in eventApps) {
      total += app.userRating!;
    }
    return total / eventApps.length;
  }

  /// Counts the total number of events hosted by a user.
  static int countEventsHosted(String hostId, List<BaratiEvent> allEvents) {
    return allEvents.where((e) => e.hostId == hostId).length;
  }
}
class CacheLogic {
  /// Strips large base64 strings from JSON data to avoid exceeding localStorage quota.
  static String getStrippedJson(dynamic data) {
    if (data is List) {
      return json.encode(data.map((item) => _stripItem(item)).toList());
    } else {
      return json.encode(_stripItem(data));
    }
  }

  static Map<String, dynamic> _stripItem(dynamic item) {
    // If item is a model, convert to Json first
    final Map<String, dynamic> map = Map<String, dynamic>.from(
      item is Map ? item : (item as dynamic).toJson()
    );
    
    // Remove base64 images (usually > 1000 chars) but keep URLs
    if (map.containsKey('profileImageUrl') && map['profileImageUrl'] != null) {
      if (map['profileImageUrl'].toString().length > 1000) {
        map['profileImageUrl'] = null; 
      }
    }
    if (map.containsKey('imageUrl') && map['imageUrl'] != null) {
      if (map['imageUrl'].toString().length > 1000) {
        map['imageUrl'] = null;
      }
    }
    return map;
  }
}
