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

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  bool _isLoading = true;
  String? _currentUserId;
  List<RoleApplication> _activities = [];
  Map<String, BaratiUser> _profilesMap = {};
  Map<String, BaratiEvent> _eventsMap = {};

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
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
              _isLoading = false;
            });
          }
        } catch (e) {
          // ignore cache errors
        }
      }

      // 2. Fetch fresh data in the background (Optimized)
      final results = await Future.wait([
        SupabaseService().getApplicationsForUser(_currentUserId!),
        SupabaseService().getApplicationsByHost(_currentUserId!),
      ]);

      final myApps = results[0];
      final hostedApps = results[1];
      
      final relevantApps = [...myApps, ...hostedApps];
      
      // Get unique IDs of events and profiles we actually need
      final eventIds = relevantApps.map((a) => a.eventId).toSet().toList();
      final applicantIds = relevantApps.map((a) => a.applicantId).toSet().toList();
      
      final freshEvents = await SupabaseService().getEventsByIds(eventIds);
      final hostIds = freshEvents.map((e) => e.hostId).toSet().toList();
      
      final freshProfiles = await SupabaseService().getProfilesByIds({...applicantIds, ...hostIds}.toList());

      final freshEventsMap = {for (var e in freshEvents) e.id: e};
      final freshProfilesMap = {for (var p in freshProfiles) p.id: p};
      
      // Sort and reverse for newest first
      final sortedApps = relevantApps.toList();
      sortedApps.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));

      if (mounted) {
        setState(() {
          _eventsMap = freshEventsMap;
          _profilesMap = freshProfilesMap;
          _activities = sortedApps;
          _isLoading = false;
        });
      }

      // 3. Update cache (Atomic & Stripped to avoid QuotaExceeded)
      try {
        prefs.setString('cached_activity_apps', CacheLogic.getStrippedJson(sortedApps.take(50).toList()));
        prefs.setString('cached_activity_events', CacheLogic.getStrippedJson(freshEvents.take(50).toList()));
        prefs.setString('cached_activity_profiles', CacheLogic.getStrippedJson(freshProfiles.take(50).toList()));
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
