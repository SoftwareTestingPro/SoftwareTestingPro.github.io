import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'add_event_screen.dart';
import 'manage_applications_screen.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/event_logic.dart';
import '../services/logic_service.dart';

class EventDetailsScreen extends StatefulWidget {
  final BaratiEvent event;
  const EventDetailsScreen({super.key, required this.event});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  List<RoleApplication> _myApplications = [];
  BaratiUser? _currentUser;
  BaratiUser? _hostUser;
  bool _isLoading = true;
  List<RoleApplication> _allApplications = [];
  Map<String, BaratiUser> _applicantProfiles = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? prefs.getString('mobileNumber') ?? 'anonymous';
    
    final profile = await SupabaseService().getProfile(userId);
    final hostProfile = await SupabaseService().getProfile(widget.event.hostId);
    final applications = await SupabaseService().getApplicationsForUserForEvent(widget.event.id, userId);
    
    if (mounted) {
      setState(() {
        _currentUser = profile;
        _hostUser = hostProfile;
        _myApplications = applications;
        _isLoading = false;
      });
      
      // If host, load all applications
      if (userId == widget.event.hostId) {
        final allApps = await SupabaseService().getApplicationsForEvent(widget.event.id);
        final allProfiles = await SupabaseService().getProfiles();
        final Map<String, BaratiUser> profileMap = {for (var p in allProfiles) p.id: p};
        
        if (mounted) {
          setState(() {
            _allApplications = allApps;
            _applicantProfiles = profileMap;
          });
        }
      }
    }
  }

  Future<void> _applyForRole(EventRole roleInfo) async {
    final messageController = TextEditingController();
    final role = roleInfo.role;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Apply for ${role.toLabel()}', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (roleInfo.description.isNotEmpty) ...[
              Text('Requirement:', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600])),
              const SizedBox(height: 4),
              Text(roleInfo.description, style: GoogleFonts.montserrat(fontSize: 14, fontStyle: FontStyle.italic)),
              const SizedBox(height: 16),
            ],
            Text('Tell the host why you\'d be a great fit for this role.', style: GoogleFonts.montserrat(fontSize: 14)),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Your message...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
            child: const Text('Apply', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == true) {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? prefs.getString('mobileNumber') ?? 'anonymous';
      
      final newApp = RoleApplication(
        id: const Uuid().v4(),
        eventId: widget.event.id,
        applicantId: userId,
        appliedRole: role,
        message: messageController.text,
      );

      final appsJson = prefs.getString('applications') ?? '[]';
      List<dynamic> appsList = json.decode(appsJson);
      appsList.add(newApp.toJson());
      await prefs.setString('applications', json.encode(appsList));

      // Save to Supabase
      await SupabaseService().applyForRole(newApp);

      _loadData(); // Refresh to get the latest application status
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEventHeader(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('About the Event'),
                  const SizedBox(height: 8),
                  Text(
                    widget.event.description,
                    style: GoogleFonts.montserrat(fontSize: 16, color: Colors.grey[800], height: 1.5),
                  ),
                  const SizedBox(height: 32),
                  Builder(
                    builder: (context) {
                      final isPast = EventLogic.isEventPast(widget.event);
                      final attendedApp = EventLogic.getApprovedApplication(_myApplications);
                      final hasAttended = isPast && attendedApp != null;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(hasAttended ? 'Role Played' : 'Roles Needed'),
                          if (_currentUser?.id != widget.event.hostId && !hasAttended) ...[
                            const SizedBox(height: 4),
                            Text(
                              isPast ? 'Event has ended.' : 'Apply for a role that matches your profile.',
                              style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                          const SizedBox(height: 12),
                          _buildRolesList(hasAttended ? attendedApp!.appliedRole : null),
                          if (hasAttended) ...[
                            const SizedBox(height: 32),
                            _buildSectionTitle('Rate Your Experience'),
                            const SizedBox(height: 16),
                            _buildRatingSection(attendedApp!, isHost: false),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/hero_bg.png', fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _eventTypeBadge(widget.event.eventType),
            Text(
              EventLogic.formatDate(widget.event.date),
              style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          widget.event.title,
          style: GoogleFonts.playfairDisplay(fontSize: 32, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.location_on, size: 18, color: Colors.redAccent),
            const SizedBox(width: 4),
            Text(
              widget.event.location,
              style: GoogleFonts.montserrat(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_hostUser != null) ...[
          _buildSectionTitle('Hosted by'),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                backgroundImage: _hostUser!.profileImageUrl != null && _hostUser!.profileImageUrl!.startsWith('http')
                    ? NetworkImage(_hostUser!.profileImageUrl!) as ImageProvider
                    : (_hostUser!.profileImageUrl != null
                        ? MemoryImage(base64Decode(_hostUser!.profileImageUrl!))
                        : null),
                child: _hostUser!.profileImageUrl == null
                    ? Icon(Icons.person, color: Theme.of(context).colorScheme.primary)
                    : null,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _hostUser!.name,
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    _hostUser!.city,
                    style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ],
        if (_currentUser?.id == widget.event.hostId) ...[
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionTitle('Applicants'),
              TextButton(
                onPressed: () => Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (context) => ManageApplicationsScreen(event: widget.event))
                ).then((_) => _loadData()),
                child: const Text('Manage'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildApplicantsList(),
        ],
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }
  Widget _buildRolesList([FamilyRole? onlyShowRole]) {
    final isHost = _currentUser?.id == widget.event.hostId;

    final filteredRoles = widget.event.neededRoles.where((roleInfo) {
      if (onlyShowRole != null) return roleInfo.role == onlyShowRole;
      if (_currentUser == null || isHost) return true;
      
      // Gender check
      if (roleInfo.gender != 'Any' && roleInfo.gender.toLowerCase() != _currentUser!.gender.toLowerCase()) {
        return false;
      }
      
      // Role match check
      return _currentUser!.possibleRoles.contains(roleInfo.role);
    }).toList();

    if (filteredRoles.isEmpty && !isHost) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              'No matching roles found for your profile.',
              style: GoogleFonts.montserrat(color: Colors.amber[900], fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'You can only apply for roles you have selected in your profile. Update your profile to add more roles.',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(color: Colors.amber[900], fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: filteredRoles.length,
      itemBuilder: (context, index) {
        final roleInfo = filteredRoles[index];
        final role = roleInfo.role;
        String label = role.toLabel();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16)),
                      Row(
                        children: [
                          if (roleInfo.gender != 'Any')
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Text(
                                roleInfo.gender,
                                style: GoogleFonts.montserrat(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600),
                              ),
                            ),
                          Text(
                            'for ${roleInfo.forWhom}',
                            style: GoogleFonts.montserrat(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Builder(
                    builder: (context) {
                      final now = DateTime.now();
                      final isPast = widget.event.date.isBefore(now);
                      final hasAppliedToThisEvent = _myApplications.isNotEmpty;
                      final application = _myApplications.firstWhere(
                        (app) => app.appliedRole == role, 
                        orElse: () => RoleApplication(id: '', eventId: '', applicantId: '', appliedRole: role, message: ''),
                      );
                      
                      final hasAppliedThisRole = application.id.isNotEmpty;
                      final isApprovedThisRole = application.isApproved;
                      final isDeclinedThisRole = application.status == ApplicationStatus.declined;
                      final isWithdrawnThisRole = application.status == ApplicationStatus.withdrawn;
                      final isHostOfEvent = widget.event.hostId == _currentUser?.id;

                      if (isPast) {
                        return Text(isApprovedThisRole ? 'Attended' : 'Event Ended', style: GoogleFonts.montserrat(color: isApprovedThisRole ? Colors.green : Colors.grey, fontWeight: FontWeight.bold));
                      }

                      String buttonText = 'Apply';
                      bool isDisabled = hasAppliedToThisEvent || isHostOfEvent;

                      if (isHostOfEvent) {
                        return const SizedBox.shrink();
                      }

                      return ElevatedButton(
                        onPressed: isDisabled ? null : () => _applyForRole(roleInfo),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isApprovedThisRole 
                            ? Colors.green 
                            : (isDeclinedThisRole ? Colors.red : Theme.of(context).colorScheme.primary),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text(buttonText),
                      );
                    },
                  ),
                ],
              ),
              if (roleInfo.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  roleInfo.description,
                  style: GoogleFonts.montserrat(fontSize: 13, color: Colors.grey[700], fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildApplicantsList() {
    if (_allApplications.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16)),
        child: Center(child: Text('No applications yet.', style: GoogleFonts.montserrat(color: Colors.grey))),
      );
    }

    return Column(
      children: _allApplications.map((app) {
        final profile = _applicantProfiles[app.applicantId];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[100]!),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: profile?.profileImageUrl != null ? MemoryImage(base64Decode(profile!.profileImageUrl!)) : null,
                child: profile?.profileImageUrl == null ? const Icon(Icons.person, size: 20) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile?.name ?? 'Anonymous', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(app.appliedRole.toLabel(), style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: app.isApproved ? Colors.green.withOpacity(0.1) : (app.status == ApplicationStatus.declined ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  app.isApproved ? 'Approved' : (app.status == ApplicationStatus.declined ? 'Declined' : (app.status == ApplicationStatus.withdrawn ? 'Withdrawn' : 'Pending')),
                  style: GoogleFonts.montserrat(
                    fontSize: 10, 
                    fontWeight: FontWeight.bold, 
                    color: app.isApproved ? Colors.green : (app.status == ApplicationStatus.declined ? Colors.red : Colors.orange),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRatingSection(RoleApplication application, {required bool isHost}) {
    final currentRating = isHost ? application.hostRating : application.userRating;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            final starValue = index + 1.0;
            final isFull = currentRating != null && currentRating >= starValue;
            
            return GestureDetector(
              onTap: () async {
                final commentController = TextEditingController(text: isHost ? application.hostComment : application.userComment);
                final result = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Rate your experience'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (i) => Icon(
                            i < starValue ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 32,
                          )),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: commentController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Add a comment (optional)...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Submit'),
                      ),
                    ],
                  ),
                );

                if (result == true) {
                  if (isHost) {
                    await SupabaseService().updateApplicationRating(
                      application.id, 
                      hostRating: starValue,
                      hostComment: commentController.text,
                    );
                  } else {
                    await SupabaseService().updateApplicationRating(
                      application.id, 
                      userRating: starValue,
                      userComment: commentController.text,
                    );
                  }
                  _loadData();
                }
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Icon(
                  isFull ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 36,
                ),
              ),
            );
          }),
        ),
        if (!isHost && application.userComment != null && application.userComment!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '"${application.userComment}"',
            style: GoogleFonts.montserrat(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey[700]),
          ),
        ],
        if (isHost && application.hostComment != null && application.hostComment!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '"${application.hostComment}"',
            style: GoogleFonts.montserrat(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey[700]),
          ),
        ],
      ],
    );
  }

  Widget _eventTypeBadge(EventType type) {
    Color color;
    switch (type) {
      case EventType.marriage: color = Colors.pink; break;
      case EventType.haldi: color = Colors.orange; break;
      case EventType.mehndi: color = Colors.green; break;
      case EventType.sangeet: color = Colors.indigo; break;
      case EventType.reception: color = Colors.deepPurple; break;
      case EventType.engagement: color = Colors.teal; break;
      case EventType.birthday: color = Colors.lightBlue; break;
      case EventType.babyShower: color = Colors.pinkAccent; break;
      case EventType.houseWarming: color = Colors.brown; break;
      case EventType.anniversary: color = Colors.amber; break;
      case EventType.death: color = Colors.black54; break;
      default: color = Colors.blue;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(
        type.name.replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}').toUpperCase(),
        style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
