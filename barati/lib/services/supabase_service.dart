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
      id: p['id'],
      name: p['name'],
      age: p['age'],
      gender: p['gender'],
      userRole: UserRole.values[p['user_role'] ?? 1],
      possibleRoles: (p['possible_roles'] as List? ?? [])
          .map((r) => FamilyRole.values[r as int])
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
      'date': event.date.toIso8601String(),
      'location': event.location,
      'event_type': event.eventType.index,
      'needed_roles': event.neededRoles.map((r) => r.toJson()).toList(),
      'approved_member_ids': event.approvedMemberIds,
    });
  }

  Future<void> updateEvent(BaratiEvent event) async {
    await client.from('events').update({
      'title': event.title,
      'description': event.description,
      'date': event.date.toIso8601String(),
      'location': event.location,
      'event_type': event.eventType.index,
      'needed_roles': event.neededRoles.map((r) => r.toJson()).toList(),
      'approved_member_ids': event.approvedMemberIds,
    }).eq('id', event.id);
  }

  Future<void> deleteEvent(String eventId) async {
    await client.from('events').delete().eq('id', eventId);
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
      date: DateTime.parse(e['date']),
      location: e['location'],
      eventType: EventType.values[e['event_type']],
      neededRoles: (e['needed_roles'] as List)
          .map((r) => r is int ? EventRole(role: FamilyRole.values[r], description: '', gender: 'Any') : EventRole.fromJson(r as Map<String, dynamic>))
          .toList(),
      approvedMemberIds: List<String>.from(e['approved_member_ids']),
    )).toList();
  }

  // --- Application Operations ---

  Future<void> applyForRole(RoleApplication app) async {
    await client.from('applications').insert({
      'id': app.id,
      'event_id': app.eventId,
      'applicant_id': app.applicantId,
      'applied_role': app.appliedRole.index,
      'message': app.message,
      'is_approved': app.isApproved,
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
      appliedRole: FamilyRole.values[app['applied_role']],
      message: app['message'],
      isApproved: app['is_approved'],
    )).toList();
  }

  Future<void> approveApplication(String applicationId, String eventId, String applicantId) async {
    // 1. Mark application as approved
    await client.from('applications').update({'is_approved': true}).eq('id', applicationId);
    
    // 2. Fetch current approved_member_ids for the event
    final eventResponse = await client.from('events').select('approved_member_ids').eq('id', eventId).single();
    List<String> approved = List<String>.from(eventResponse['approved_member_ids']);
    
    if (!approved.contains(applicantId)) {
      approved.add(applicantId);
      // 3. Update event's approved_member_ids
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
}
