import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

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

  Future<List<BaratiUser>> getProfiles() async {
    final response = await client
        .from('profiles')
        .select();
    
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

  Future<List<BaratiEvent>> getEvents() async {
    final response = await client
        .from('events')
        .select()
        .order('date', ascending: true);
    
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

  Future<List<RoleApplication>> getApplicationsForUser(String userId) async {
    final response = await client
        .from('applications')
        .select()
        .eq('applicant_id', userId);
    
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
