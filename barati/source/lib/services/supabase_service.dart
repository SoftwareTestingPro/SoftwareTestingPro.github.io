import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import 'package:flutter/foundation.dart';

class SupabaseService {
  static final client = Supabase.instance.client;

  // --- Profile Operations ---
  
  Future<void> upsertProfile(BaratiUser user) async {
    await client.from('profiles').upsert({
      'id': user.id,
      'name': user.name,
      'age': user.age,
      'gender': user.gender,
      'user_role': user.userRole.index,
      'possible_roles': user.possibleRoles.map((r) => r.index).toList(),
      'bio': user.bio,
      'profile_image_url': user.profileImageUrl,
      'city': user.city,
      'state': user.state,
      'profession': user.profession,
      'education': user.education,
      'languages': user.languages,
    });
  }

  Future<BaratiUser?> getProfile(String userId) async {
    final response = await client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    
    if (response == null) return null;
    
    return BaratiUser(
      id: response['id'],
      name: response['name'],
      age: response['age'],
      gender: response['gender'],
      userRole: UserRole.values[response['user_role'] ?? 1],
      possibleRoles: (response['possible_roles'] as List? ?? [])
          .map((r) => FamilyRole.values[r as int])
          .toList(),
      bio: response['bio'] ?? '',
      profileImageUrl: response['profile_image_url'],
      city: response['city'] ?? '',
      state: response['state'] ?? '',
      profession: response['profession'] ?? '',
      education: response['education'] ?? '',
      languages: List<String>.from(response['languages'] ?? []),
    );
  }

  Future<List<BaratiUser>> getProfiles({int limit = 100}) async {
    // Optimization: Skip bio, education, languages etc. for the global list
    const profileColumns = 'id,name,age,gender,user_role,possible_roles,profile_image_url,city,state';
    
    final response = await client
        .from('profiles')
        .select(profileColumns)
        .limit(limit);
    
    return (response as List).map((p) => BaratiUser(
      id: p['id'] ?? '',
      name: p['name'] ?? 'Anonymous',
      age: p['age'] ?? 25,
      gender: p['gender'] ?? 'Other',
      userRole: p['user_role'] != null && p['user_role'] < UserRole.values.length 
          ? UserRole.values[p['user_role']] 
          : UserRole.baratiMember,
      possibleRoles: (p['possible_roles'] as List? ?? [])
          .map((r) {
            int index = r as int;
            if (index < FamilyRole.values.length) {
              return FamilyRole.values[index];
            }
            return FamilyRole.other;
          })
          .toList(),
      bio: '', // Skip in list
      profileImageUrl: p['profile_image_url'],
      city: p['city'] ?? '',
      state: p['state'] ?? '',
      profession: '', // Skip in list
      education: '', // Skip in list
      languages: [], // Skip in list
    )).toList();
  }

  Future<List<BaratiUser>> getProfilesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final response = await client
        .from('profiles')
        .select()
        .filter('id', 'in', ids);
    
    return (response as List).map((p) => BaratiUser(
      id: p['id'] ?? '',
      name: p['name'] ?? 'Anonymous',
      age: p['age'] ?? 25,
      gender: p['gender'] ?? 'Other',
      userRole: p['user_role'] != null && p['user_role'] < UserRole.values.length 
          ? UserRole.values[p['user_role']] 
          : UserRole.baratiMember,
      possibleRoles: (p['possible_roles'] as List? ?? [])
          .map((r) {
            int index = r as int;
            if (index < FamilyRole.values.length) {
              return FamilyRole.values[index];
            }
            return FamilyRole.other;
          })
          .toList(),
      bio: p['bio'] ?? '',
      profileImageUrl: p['profile_image_url'],
      city: p['city'] ?? '',
      state: p['state'] ?? '',
      profession: p['profession'] ?? '',
      education: p['education'] ?? '',
      languages: List<String>.from(p['languages'] ?? []),
    )).toList();
  }

  // --- Event Operations ---

  Future<void> createEvent(BaratiEvent event) async {
    await client.from('events').insert({
      'id': event.id,
      'host_id': event.hostId,
      'title': event.title,
      'description': event.description,
      'date': event.date.toUtc().toIso8601String(),
      'location': event.location,
      'event_type': event.eventType.index,
      'needed_roles': event.neededRoles.map((r) => r.toJson()).toList(),
      'approved_member_ids': event.approvedMemberIds,
      'image_url': event.imageUrl,
      'city': event.city,
      'state': event.state,
    });
  }

  Future<void> updateEvent(BaratiEvent event) async {
    await client.from('events').update({
      'title': event.title,
      'description': event.description,
      'date': event.date.toUtc().toIso8601String(),
      'location': event.location,
      'event_type': event.eventType.index,
      'needed_roles': event.neededRoles.map((r) => r.toJson()).toList(),
      'approved_member_ids': event.approvedMemberIds,
      'image_url': event.imageUrl,
      'city': event.city,
      'state': event.state,
    }).eq('id', event.id);
  }

  Future<List<BaratiEvent>> getEvents({int limit = 200}) async {
    // Fetch events from the last 180 days (6 months) and all future events.
    // Optimization: Skip description and image_url for global list
    const eventColumns = 'id,host_id,title,date,location,city,state,event_type,needed_roles,approved_member_ids';
    final sixMonthsAgo = DateTime.now().subtract(const Duration(days: 180)).toUtc().toIso8601String();
    
    final response = await client
        .from('events')
        .select(eventColumns)
        .gte('date', sixMonthsAgo)
        .order('date', ascending: true)
        .limit(limit);
    
    return (response as List).map((e) => BaratiEvent(
      id: e['id'],
      hostId: e['host_id'],
      title: e['title'],
      description: '', // Skip in list
      date: DateTime.parse(e['date'].toString().endsWith('Z') || e['date'].toString().contains('+') || e['date'].toString().contains(RegExp(r'-\d{2}:\d{2}$')) ? e['date'] : '${e['date']}Z').toLocal(),
      location: e['location'],
      city: e['city'] ?? '',
      state: e['state'] ?? '',
      eventType: (e['event_type'] ?? 0) < EventType.values.length ? EventType.values[e['event_type'] ?? 0] : EventType.other,
      neededRoles: (e['needed_roles'] as List? ?? [])
          .map((r) => r is int ? EventRole(role: r < FamilyRole.values.length ? FamilyRole.values[r] : FamilyRole.other, description: '', gender: 'Any') : EventRole.fromJson(r as Map<String, dynamic>))
          .toList(),
      approvedMemberIds: List<String>.from(e['approved_member_ids'] ?? []),
      imageUrl: 'assets/images/${((e['event_type'] ?? 0) < EventType.values.length ? EventType.values[e['event_type'] ?? 0] : EventType.other).name}.jpg', // Use default for list
    )).toList();
  }

  Future<List<BaratiEvent>> getEventsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final response = await client
        .from('events')
        .select()
        .filter('id', 'in', ids);
    
    return (response as List).map((e) => BaratiEvent(
      id: e['id'],
      hostId: e['host_id'],
      title: e['title'],
      description: e['description'],
      date: DateTime.parse(e['date'].toString().endsWith('Z') || e['date'].toString().contains('+') || e['date'].toString().contains(RegExp(r'-\d{2}:\d{2}$')) ? e['date'] : '${e['date']}Z').toLocal(),
      location: e['location'],
      city: e['city'] ?? '',
      state: e['state'] ?? '',
      eventType: (e['event_type'] ?? 0) < EventType.values.length ? EventType.values[e['event_type'] ?? 0] : EventType.other,
      neededRoles: (e['needed_roles'] as List)
          .map((r) => r is int ? EventRole(role: r < FamilyRole.values.length ? FamilyRole.values[r] : FamilyRole.other, description: '', gender: 'Any') : EventRole.fromJson(r as Map<String, dynamic>))
          .toList(),
      approvedMemberIds: List<String>.from(e['approved_member_ids']),
      imageUrl: (e['image_url'] != null && (e['image_url'].toString().startsWith('assets/') || e['image_url'].toString().startsWith('/9j/'))) 
          ? e['image_url'] 
          : 'assets/images/${((e['event_type'] ?? 0) < EventType.values.length ? EventType.values[e['event_type'] ?? 0] : EventType.other).name}.jpg',
    )).toList();
  }

  Future<List<BaratiEvent>> getEventsByHost(String hostId) async {
    final response = await client
        .from('events')
        .select()
        .eq('host_id', hostId)
        .order('date', ascending: false);
    
    return (response as List).map((e) => BaratiEvent(
      id: e['id'],
      hostId: e['host_id'],
      title: e['title'],
      description: e['description'],
      date: DateTime.parse(e['date'].toString().endsWith('Z') || e['date'].toString().contains('+') || e['date'].toString().contains(RegExp(r'-\d{2}:\d{2}$')) ? e['date'] : '${e['date']}Z').toLocal(),
      location: e['location'],
      city: e['city'] ?? '',
      state: e['state'] ?? '',
      eventType: (e['event_type'] ?? 0) < EventType.values.length ? EventType.values[e['event_type'] ?? 0] : EventType.other,
      neededRoles: (e['needed_roles'] as List)
          .map((r) => r is int ? EventRole(role: r < FamilyRole.values.length ? FamilyRole.values[r] : FamilyRole.other, description: '', gender: 'Any') : EventRole.fromJson(r as Map<String, dynamic>))
          .toList(),
      approvedMemberIds: List<String>.from(e['approved_member_ids']),
      imageUrl: (e['image_url'] != null && (e['image_url'].toString().startsWith('assets/') || e['image_url'].toString().startsWith('/9j/'))) 
          ? e['image_url'] 
          : 'assets/images/${((e['event_type'] ?? 0) < EventType.values.length ? EventType.values[e['event_type'] ?? 0] : EventType.other).name}.jpg',
    )).toList();
  }

  Future<List<BaratiEvent>> getEventsParticipated(String userId) async {
    // 1. Get IDs of events where user is an approved guest
    final apps = await client
        .from('applications')
        .select('event_id')
        .eq('applicant_id', userId)
        .eq('status', ApplicationStatus.approved.index);
    
    final ids = (apps as List).map((a) => a['event_id'] as String).toList();
    if (ids.isEmpty) return [];

    // 2. Fetch those events
    return await getEventsByIds(ids);
  }

  // --- Application Operations ---

  Future<void> deleteEvent(String eventId) async {
    // 1. Delete associated applications
    await client.from('applications').delete().eq('event_id', eventId);
    // 2. Delete the event
    await client.from('events').delete().eq('id', eventId);
  }

  Future<void> updateApplicationRating(String applicationId, {double? userRating, double? hostRating, String? userComment, String? hostComment}) async {
    final updates = <String, dynamic>{};
    if (userRating != null) updates['user_rating'] = userRating;
    if (hostRating != null) updates['host_rating'] = hostRating;
    if (userComment != null) updates['user_comment'] = userComment;
    if (hostComment != null) updates['host_comment'] = hostComment;
    
    if (updates.isNotEmpty) {
      await client.from('applications').update(updates).eq('id', applicationId);
    }
  }

  Future<void> applyForRole(RoleApplication app) async {
    await client.from('applications').insert({
      'id': app.id,
      'event_id': app.eventId,
      'applicant_id': app.applicantId,
      'applied_role': app.appliedRole.index,
      'message': app.message,
      'is_approved': app.isApproved,
      'status': app.status.index,
      'is_invitation': app.isInvitation,
    });
  }

  Future<List<RoleApplication>> getApplicationsForEvent(String eventId) async {
    final response = await client
        .from('applications')
        .select()
        .eq('event_id', eventId);
    
    return (response as List).map((app) => RoleApplication(
      id: app['id'],
      eventId: app['event_id'],
      applicantId: app['applicant_id'],
      appliedRole: (app['applied_role'] ?? 0) < FamilyRole.values.length ? FamilyRole.values[app['applied_role'] ?? 0] : FamilyRole.other,
      message: app['message'],
      isApproved: app['is_approved'],
      status: (app['status'] ?? 0) < ApplicationStatus.values.length ? ApplicationStatus.values[app['status'] ?? 0] : ApplicationStatus.pending,
      isInvitation: app['is_invitation'] ?? false,
      userRating: app['user_rating']?.toDouble(),
      hostRating: app['host_rating']?.toDouble(),
      userComment: app['user_comment'],
      hostComment: app['host_comment'],
      createdAt: app['created_at'] != null ? DateTime.parse(app['created_at'].toString().endsWith('Z') || app['created_at'].toString().contains('+') || app['created_at'].toString().contains(RegExp(r'-\d{2}:\d{2}$')) ? app['created_at'] : '${app['created_at']}Z').toLocal() : null,
    )).toList();
  }

  Future<void> approveApplication(String applicationId, String eventId, String applicantId) async {
    // 1. Mark application as approved
    await client.from('applications').update({
      'is_approved': true,
      'status': ApplicationStatus.approved.index,
    }).eq('id', applicationId);
    
    // 2. Fetch current approved_member_ids for the event
    final eventResponse = await client.from('events').select('approved_member_ids').eq('id', eventId).single();
    List<String> approved = List<String>.from(eventResponse['approved_member_ids']);
    
    if (!approved.contains(applicantId)) {
      approved.add(applicantId);
      // 3. Update event's approved_member_ids
      await client.from('events').update({'approved_member_ids': approved}).eq('id', eventId);
    }
  }

  Future<void> declineApplication(String applicationId) async {
    await client.from('applications').update({
      'is_approved': false,
      'status': ApplicationStatus.declined.index,
    }).eq('id', applicationId);
  }

  Future<void> respondToInvitation(String applicationId, bool accept, String eventId, String userId) async {
    if (accept) {
      await approveApplication(applicationId, eventId, userId);
      await client.from('applications').update({
        'status': ApplicationStatus.invitationAccepted.index,
      }).eq('id', applicationId);
    } else {
      await client.from('applications').update({
        'status': ApplicationStatus.invitationDeclined.index,
      }).eq('id', applicationId);
    }
  }

  Future<void> cancelApplication(String applicationId, String eventId, String userId) async {
    // 1. Mark application as withdrawn
    await client.from('applications').update({
      'is_approved': false,
      'status': ApplicationStatus.withdrawn.index,
    }).eq('id', applicationId);
    
    // 2. Remove user from approved_member_ids in event
    final eventResponse = await client.from('events').select('approved_member_ids').eq('id', eventId).single();
    List<String> approved = List<String>.from(eventResponse['approved_member_ids']);
    
    if (approved.contains(userId)) {
      approved.remove(userId);
      await client.from('events').update({'approved_member_ids': approved}).eq('id', eventId);
    }
  }

  Future<bool> hasApplied(String eventId, String applicantId) async {
    final response = await client
        .from('applications')
        .select()
        .eq('event_id', eventId)
        .eq('applicant_id', applicantId)
        .maybeSingle();
    return response != null;
  }

  Future<List<RoleApplication>> getApplicationsForUserForEvent(String eventId, String applicantId) async {
    final response = await client
        .from('applications')
        .select()
        .eq('event_id', eventId)
        .eq('applicant_id', applicantId);
    
    return (response as List).map((app) => RoleApplication(
      id: app['id'],
      eventId: app['event_id'],
      applicantId: app['applicant_id'],
      appliedRole: (app['applied_role'] ?? 0) < FamilyRole.values.length ? FamilyRole.values[app['applied_role'] ?? 0] : FamilyRole.other,
      message: app['message'],
      isApproved: app['is_approved'],
      status: (app['status'] ?? 0) < ApplicationStatus.values.length ? ApplicationStatus.values[app['status'] ?? 0] : ApplicationStatus.pending,
      isInvitation: app['is_invitation'] ?? false,
      userRating: app['user_rating']?.toDouble(),
      hostRating: app['host_rating']?.toDouble(),
      userComment: app['user_comment'],
      hostComment: app['host_comment'],
      createdAt: app['created_at'] != null ? DateTime.parse(app['created_at'].toString().endsWith('Z') || app['created_at'].toString().contains('+') || app['created_at'].toString().contains(RegExp(r'-\d{2}:\d{2}$')) ? app['created_at'] : '${app['created_at']}Z').toLocal() : null,
    )).toList();
  }

  Future<List<RoleApplication>> getApplicationsForUser(String userId, {int limit = 50}) async {
    final response = await client
        .from('applications')
        .select()
        .eq('applicant_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    
    return (response as List).map((app) => RoleApplication(
      id: app['id'],
      eventId: app['event_id'],
      applicantId: app['applicant_id'],
      appliedRole: (app['applied_role'] ?? 0) < FamilyRole.values.length ? FamilyRole.values[app['applied_role'] ?? 0] : FamilyRole.other,
      message: app['message'],
      isApproved: app['is_approved'],
      status: (app['status'] ?? 0) < ApplicationStatus.values.length ? ApplicationStatus.values[app['status'] ?? 0] : ApplicationStatus.pending,
      isInvitation: app['is_invitation'] ?? false,
      userRating: app['user_rating']?.toDouble(),
      hostRating: app['host_rating']?.toDouble(),
      userComment: app['user_comment'],
      hostComment: app['host_comment'],
      createdAt: app['created_at'] != null ? DateTime.parse(app['created_at'].toString().endsWith('Z') || app['created_at'].toString().contains('+') || app['created_at'].toString().contains(RegExp(r'-\d{2}:\d{2}$')) ? app['created_at'] : '${app['created_at']}Z').toLocal() : null,
    )).toList();
  }

  Future<List<RoleApplication>> getAllApplications() async {
    final response = await client
        .from('applications')
        .select();
    
    return (response as List).map((app) => RoleApplication(
      id: app['id'],
      eventId: app['event_id'],
      applicantId: app['applicant_id'],
      appliedRole: (app['applied_role'] ?? 0) < FamilyRole.values.length ? FamilyRole.values[app['applied_role'] ?? 0] : FamilyRole.other,
      message: app['message'],
      isApproved: app['is_approved'],
      status: (app['status'] ?? 0) < ApplicationStatus.values.length ? ApplicationStatus.values[app['status'] ?? 0] : ApplicationStatus.pending,
      isInvitation: app['is_invitation'] ?? false,
      userRating: app['user_rating']?.toDouble(),
      hostRating: app['host_rating']?.toDouble(),
      userComment: app['user_comment'],
      hostComment: app['host_comment'],
      createdAt: app['created_at'] != null ? DateTime.parse(app['created_at'].toString().endsWith('Z') || app['created_at'].toString().contains('+') || app['created_at'].toString().contains(RegExp(r'-\d{2}:\d{2}$')) ? app['created_at'] : '${app['created_at']}Z').toLocal() : null,
    )).toList();
  }

  Future<List<Map<String, dynamic>>> getActivityFeed(String userId) async {
    try {
      // 1. Fetch applications where I am the applicant (Fast)
      final myAppsResponse = await client.from('applications')
          .select('id,event_id,applicant_id,applied_role,message,is_approved,status,is_invitation,created_at')
          .eq('applicant_id', userId)
          .order('created_at', ascending: false)
          .limit(60);
      
      // 2. Fetch my hosted events
      final myEventsResponse = await client.from('events').select('id').eq('host_id', userId);
      final myEventIds = (myEventsResponse as List).map((e) => e['id'].toString()).toList();
      
      List<dynamic> hostAppsResponse = [];
      if (myEventIds.isNotEmpty) {
        hostAppsResponse = await client.from('applications')
            .select('id,event_id,applicant_id,applied_role,message,is_approved,status,is_invitation,created_at')
            .filter('event_id', 'in', myEventIds)
            .order('created_at', ascending: false)
            .limit(60);
      }

      final allRawApps = [...(myAppsResponse as List), ...hostAppsResponse];
      if (allRawApps.isEmpty) return [];

      // Remove duplicates by ID
      final Map<String, Map<String, dynamic>> uniqueApps = {};
      for (var a in allRawApps) {
        final id = a['id'].toString();
        uniqueApps[id] = Map<String, dynamic>.from(a);
      }
      
      final uniqueAppList = uniqueApps.values.toList();

      // 3. Collect unique IDs for Details
      final eventIds = uniqueAppList.map((a) => a['event_id'].toString()).toSet().toList();
      
      // We need BOTH applicant IDs and Host IDs for full messages
      final userIdsToFetch = uniqueAppList.map((a) => a['applicant_id'].toString()).toSet();
      
      // 4. Fetch Events first so we can get their host IDs
      final events = await getEventsByIds(eventIds);
      final eventsMap = {for (var e in events) e.id: e};
      
      for (var e in events) {
        userIdsToFetch.add(e.hostId);
      }

      // 5. Fetch all Profiles in one batch
      final profiles = await getProfilesByIds(userIdsToFetch.toList());
      final profilesMap = {for (var p in profiles) p.id: p};

      // 6. Merge Locally with safety
      final List<Map<String, dynamic>> merged = uniqueAppList.map((a) {
        final event = eventsMap[a['event_id'].toString()];
        final applicant = profilesMap[a['applicant_id'].toString()];
        final host = event != null ? profilesMap[event.hostId] : null;
        
        final Map<String, dynamic> result = Map<String, dynamic>.from(a);
        
        result['events'] = event != null ? {
          'id': event.id,
          'title': event.title,
          'date': event.date.toIso8601String(),
          'location': event.location,
          'event_type': event.eventType.index,
          'host_id': event.hostId,
          'city': event.city,
          'state': event.state,
          'needed_roles': event.neededRoles.map((r) => r.toJson()).toList(),
          'approved_member_ids': event.approvedMemberIds,
          'image_url': event.imageUrl,
          'host': host != null ? {
            'id': host.id,
            'name': host.name,
            'profile_image_url': host.profileImageUrl,
            'user_role': host.userRole.index,
          } : null,
        } : null;

        result['applicant'] = applicant != null ? {
          'id': applicant.id,
          'name': applicant.name,
          'profile_image_url': applicant.profileImageUrl,
          'user_role': applicant.userRole.index,
        } : null;

        return result;
      }).toList();

      merged.sort((a, b) => (b['created_at'] ?? '').toString().compareTo((a['created_at'] ?? '').toString()));
      return merged;
    } catch (e) {
      debugPrint('Critical error in fragmented activity feed: $e');
      return [];
    }
  }

  Future<List<RoleApplication>> getApplicationsByHost(String hostId, {int limit = 50}) async {
    // Optimized to use a join filter to avoid two sequential requests
    final response = await client
        .from('applications')
        .select('*, events!inner(host_id)')
        .eq('events.host_id', hostId)
        .order('created_at', ascending: false)
        .limit(limit);
    
    return (response as List).map((app) => RoleApplication(
      id: app['id'],
      eventId: app['event_id'],
      applicantId: app['applicant_id'],
      appliedRole: (app['applied_role'] ?? 0) < FamilyRole.values.length ? FamilyRole.values[app['applied_role'] ?? 0] : FamilyRole.other,
      message: app['message'],
      isApproved: app['is_approved'],
      status: (app['status'] ?? 0) < ApplicationStatus.values.length ? ApplicationStatus.values[app['status'] ?? 0] : ApplicationStatus.pending,
      isInvitation: app['is_invitation'] ?? false,
      userRating: app['user_rating']?.toDouble(),
      hostRating: app['host_rating']?.toDouble(),
      userComment: app['user_comment'],
      hostComment: app['host_comment'],
      createdAt: app['created_at'] != null ? DateTime.parse(app['created_at'].toString().endsWith('Z') || app['created_at'].toString().contains('+') || app['created_at'].toString().contains(RegExp(r'-\d{2}:\d{2}$')) ? app['created_at'] : '${app['created_at']}Z').toLocal() : null,
    )).toList();
  }

  Future<void> deleteProfile(String userId) async {
    // 1. Get all events hosted by user
    final hostedEvents = await client.from('events').select('id').eq('host_id', userId);
    for (var event in hostedEvents) {
      await deleteEvent(event['id']);
    }

    // 2. Remove user from approved_member_ids of other events they joined
    final eventsJoined = await client.from('events').select('id, approved_member_ids').contains('approved_member_ids', [userId]);
    for (var event in eventsJoined) {
      List<String> approved = List<String>.from(event['approved_member_ids']);
      approved.remove(userId);
      await client.from('events').update({'approved_member_ids': approved}).eq('id', event['id']);
    }

    // 3. Delete all applications by user (participation info)
    await client.from('applications').delete().eq('applicant_id', userId);

    // 4. Delete the profile itself
    await client.from('profiles').delete().eq('id', userId);
  }
}
