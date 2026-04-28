import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/event_logic.dart';
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

      final allApps = await SupabaseService().getAllApplications();
      final allEvents = await SupabaseService().getEvents();
      final allProfiles = await SupabaseService().getProfiles();

      _eventsMap = {for (var e in allEvents) e.id: e};
      _profilesMap = {for (var p in allProfiles) p.id: p};

      List<RoleApplication> relevantApps = [];
      for (var app in allApps) {
        final event = _eventsMap[app.eventId];
        if (event == null) continue;

        // Skip my own actions applied to my own events (if any)
        if (app.applicantId == _currentUserId && event.hostId == _currentUserId) continue;

        if (app.applicantId == _currentUserId || event.hostId == _currentUserId) {
          relevantApps.add(app);
        }
      }
      
      // We can reverse the list to show newest first, assuming they are added chronologically in backend
      relevantApps = relevantApps.reversed.toList();

      if (mounted) {
        setState(() {
          _activities = relevantApps;
          _isLoading = false;
        });
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
      appBar: AppBar(
        title: Text('Activity', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          _buildPageBackground(),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
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
