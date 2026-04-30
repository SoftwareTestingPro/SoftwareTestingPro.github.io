import 'package:flutter/material.dart';
import '../widgets/barati_loader.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/event_logic.dart';
import '../services/logic_service.dart';
import 'event_details_screen.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  // Global cache to allow background pre-loading from other screens
  static List<RoleApplication> cachedActivities = [];
  static Map<String, BaratiEvent> cachedEvents = {};
  static Map<String, BaratiUser> cachedProfiles = {};
  static DateTime? lastGlobalLoad;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  String? _currentUserId;
  List<RoleApplication> _activities = ActivityScreen.cachedActivities;
  Map<String, BaratiUser> _profilesMap = ActivityScreen.cachedProfiles;
  Map<String, BaratiEvent> _eventsMap = ActivityScreen.cachedEvents;
  DateTime? _lastLoadTime = ActivityScreen.lastGlobalLoad;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    // If we have cached data that is less than 5 minutes old, use it immediately
    if (ActivityScreen.lastGlobalLoad != null && 
        DateTime.now().difference(ActivityScreen.lastGlobalLoad!).inMinutes < 5 && 
        ActivityScreen.cachedActivities.isNotEmpty) {
      setState(() {
        _activities = ActivityScreen.cachedActivities;
        _eventsMap = ActivityScreen.cachedEvents;
        _profilesMap = ActivityScreen.cachedProfiles;
        _lastLoadTime = ActivityScreen.lastGlobalLoad;
        _isLoading = false;
      });
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUserId = prefs.getString('user_id') ?? prefs.getString('mobileNumber');
      if (_currentUserId == null) return;

      // 1. Try to load from cache first for instant UI
      final cachedApps = prefs.getString('cached_activity_apps');
      final cachedEvents = prefs.getString('cached_activity_events');
      final cachedProfiles = prefs.getString('cached_activity_profiles');

      if (cachedApps != null && cachedEvents != null && cachedProfiles != null) {
        try {
          final appsList = jsonDecode(cachedApps) as List;
          final eventsList = jsonDecode(cachedEvents) as List;
          final profilesList = jsonDecode(cachedProfiles) as List;

          final cApps = appsList.map((e) => RoleApplication.fromJson(e)).toList();
          final cEvents = eventsList.map((e) => BaratiEvent.fromJson(e)).toList();
          final cProfiles = profilesList.map((p) => BaratiUser.fromJson(p)).toList();

          if (mounted) {
            setState(() {
              _eventsMap = {for (var e in cEvents) e.id: e};
              _profilesMap = {for (var p in cProfiles) p.id: p};
              _activities = cApps;
              _lastLoadTime = DateTime.now();
              _isLoading = false;
            });
          }
        } catch (e) {
          // ignore cache errors
        }
      }

      // 2. Fetch fresh data in the background (Optimized single-query fetch)
      final feed = await SupabaseService().getActivityFeed(_currentUserId!);

      final List<RoleApplication> freshApps = [];
      final Map<String, BaratiEvent> freshEventsMap = {};
      final Map<String, BaratiUser> freshProfilesMap = {};

      for (var item in feed) {
        try {
          // Parse Application
          final app = RoleApplication(
            id: item['id'],
            eventId: item['event_id'],
            applicantId: item['applicant_id'],
            appliedRole: (item['applied_role'] ?? 0) < FamilyRole.values.length ? FamilyRole.values[item['applied_role'] ?? 0] : FamilyRole.other,
            message: item['message'],
            isApproved: item['is_approved'],
            status: (item['status'] ?? 0) < ApplicationStatus.values.length ? ApplicationStatus.values[item['status'] ?? 0] : ApplicationStatus.pending,
            isInvitation: item['is_invitation'] ?? false,
            createdAt: item['created_at'] != null ? DateTime.parse(item['created_at']).toLocal() : null,
          );
          freshApps.add(app);

          // Parse Event
          final e = item['events'];
          if (e != null) {
            final event = BaratiEvent(
              id: e['id'] ?? '',
              hostId: e['host_id'] ?? '',
              title: e['title'] ?? 'Untitled Event',
              description: e['description'] ?? '',
              date: e['date'] != null ? DateTime.parse(e['date']).toLocal() : DateTime.now(),
              location: e['location'] ?? '',
              city: e['city'] ?? '',
              state: e['state'] ?? '',
              eventType: (e['event_type'] ?? 0) < EventType.values.length ? EventType.values[e['event_type'] ?? 0] : EventType.other,
              neededRoles: (e['needed_roles'] as List? ?? []).map((r) => EventRole.fromJson(r as Map<String, dynamic>)).toList(),
              approvedMemberIds: List<String>.from(e['approved_member_ids'] ?? []),
              imageUrl: e['image_url'] ?? '',
            );
            freshEventsMap[event.id] = event;

            // Parse Host Profile
            final h = e['host'];
            if (h != null) {
              final host = BaratiUser(
                id: h['id'] ?? '',
                name: h['name'] ?? 'Anonymous',
                age: h['age'] ?? 25,
                gender: h['gender'] ?? 'Other',
                userRole: (h['user_role'] ?? 1) < UserRole.values.length ? UserRole.values[h['user_role'] ?? 1] : UserRole.baratiMember,
                possibleRoles: (h['possible_roles'] as List? ?? []).map((r) => FamilyRole.values[r as int]).toList(),
                bio: h['bio'] ?? '',
                profileImageUrl: h['profile_image_url'],
                city: h['city'] ?? '',
                state: h['state'] ?? '',
                profession: h['profession'] ?? '',
                education: h['education'] ?? '',
                languages: List<String>.from(h['languages'] ?? []),
              );
              freshProfilesMap[host.id] = host;
            }
          }

          // Parse Applicant Profile
          final a = item['applicant'];
          if (a != null) {
            final applicant = BaratiUser(
              id: a['id'] ?? '',
              name: a['name'] ?? 'Anonymous',
              age: a['age'] ?? 25,
              gender: a['gender'] ?? 'Other',
              userRole: (a['user_role'] ?? 1) < UserRole.values.length ? UserRole.values[a['user_role'] ?? 1] : UserRole.baratiMember,
              possibleRoles: (a['possible_roles'] as List? ?? []).map((r) => FamilyRole.values[r as int]).toList(),
              bio: a['bio'] ?? '',
              profileImageUrl: a['profile_image_url'],
              city: a['city'] ?? '',
              state: a['state'] ?? '',
              profession: a['profession'] ?? '',
              education: a['education'] ?? '',
              languages: List<String>.from(a['languages'] ?? []),
            );
            freshProfilesMap[applicant.id] = applicant;
          }
        } catch (e) {
          debugPrint('Error parsing activity item: $e');
        }
      }

      if (mounted) {
        setState(() {
          // Update global cache
          ActivityScreen.cachedActivities = freshApps;
          ActivityScreen.cachedEvents = freshEventsMap;
          ActivityScreen.cachedProfiles = freshProfilesMap;
          ActivityScreen.lastGlobalLoad = DateTime.now();

          _eventsMap = freshEventsMap;
          _profilesMap = freshProfilesMap;
          _activities = freshApps;
          _lastLoadTime = ActivityScreen.lastGlobalLoad;
          _isLoading = false;
        });
      }

      // 3. Update cache (Atomic & Stripped to avoid QuotaExceeded)
      try {
        prefs.setString('cached_activity_apps', CacheLogic.getStrippedJson(freshApps.take(50).toList()));
        prefs.setString('cached_activity_events', CacheLogic.getStrippedJson(freshEventsMap.values.take(50).toList()));
        prefs.setString('cached_activity_profiles', CacheLogic.getStrippedJson(freshProfilesMap.values.take(50).toList()));
      } catch (e) {
        debugPrint('Failed to update activity cache: $e');
      }

    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getActivityMessage(RoleApplication app, BaratiEvent event) {
    final applicant = _profilesMap[app.applicantId];
    final host = _profilesMap[event.hostId];
    
    final applicantName = applicant?.name.split(' ')[0] ?? 'Someone';
    final hostName = host?.name.split(' ')[0] ?? 'Someone';
    final eventTitle = event.title;
    
    String msg = '';

    if (app.applicantId == _currentUserId) {
      // I am the guest
      if (app.isInvitation) {
        if (app.status == ApplicationStatus.invitationPending) {
          msg = '$hostName requested you to join their event $eventTitle.';
        } else if (app.status == ApplicationStatus.invitationAccepted) {
          msg = 'You accepted $hostName\'s request to join their event $eventTitle.';
        } else if (app.status == ApplicationStatus.invitationDeclined) {
          msg = 'You declined $hostName\'s request to join their event $eventTitle.';
        }
      } else {
        if (app.status == ApplicationStatus.pending) {
          msg = 'You requested to join $hostName\'s event $eventTitle.';
        } else if (app.status == ApplicationStatus.approved) {
          msg = '$hostName approved your request to join their event $eventTitle.';
        } else if (app.status == ApplicationStatus.declined) {
          msg = '$hostName declined your request to join their event $eventTitle.';
        } else if (app.status == ApplicationStatus.withdrawn) {
          msg = 'You withdrew your request to join $hostName\'s event $eventTitle.';
        }
      }
    } else if (event.hostId == _currentUserId) {
      // I am the host
      if (app.isInvitation) {
        if (app.status == ApplicationStatus.invitationPending) {
          msg = 'You requested $applicantName to join your event $eventTitle.';
        } else if (app.status == ApplicationStatus.invitationAccepted) {
          msg = '$applicantName accepted your request to join your event $eventTitle.';
        } else if (app.status == ApplicationStatus.invitationDeclined) {
          msg = '$applicantName declined your request to join your event $eventTitle.';
        }
      } else {
        if (app.status == ApplicationStatus.pending) {
          msg = '$applicantName requested to join your event $eventTitle.';
        } else if (app.status == ApplicationStatus.approved) {
          msg = 'You approved $applicantName\'s request to join your event $eventTitle.';
        } else if (app.status == ApplicationStatus.declined) {
          msg = 'You declined $applicantName\'s request to join your event $eventTitle.';
        } else if (app.status == ApplicationStatus.withdrawn) {
          msg = '$applicantName withdrew their request to join your event $eventTitle.';
        }
      }
    }
    if (msg.isEmpty) msg = 'Activity on $eventTitle';
    return msg[0].toUpperCase() + msg.substring(1);
  }

  Widget _buildPageBackground() {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/app_background.png'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Stack(
        children: [
          _buildPageBackground(),
          _isLoading
              ? const Center(child: BaratiLoader(isFullScreen: false))
              : _activities.isEmpty
                  ? Center(
                      child: Text(
                        'No activities yet.',
                        style: GoogleFonts.montserrat(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                  itemCount: _activities.length,
                  itemBuilder: (context, index) {
                    final app = _activities[index];
                    final event = _eventsMap[app.eventId];
                    if (event == null) return const SizedBox.shrink();

                    final otherPerson = (app.applicantId == _currentUserId) ? _profilesMap[event.hostId] : _profilesMap[app.applicantId];
                    final imageUrl = otherPerson?.profileImageUrl;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => EventDetailsScreen(event: event)),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                backgroundImage: imageUrl != null && imageUrl.startsWith('http')
                                    ? NetworkImage(imageUrl) as ImageProvider
                                    : imageUrl != null
                                        ? MemoryImage(base64Decode(imageUrl))
                                        : null,
                                child: imageUrl == null
                                    ? Icon(Icons.person, color: Theme.of(context).colorScheme.primary)
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getActivityMessage(app, event),
                                      style: GoogleFonts.montserrat(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            app.appliedRole.toLabel(),
                                            style: GoogleFonts.montserrat(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          if (app.createdAt != null)
                                            Text(
                                              EventLogic.formatDateTime(app.createdAt!),
                                              style: GoogleFonts.montserrat(
                                                fontSize: 10,
                                                color: Colors.grey[500],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}
