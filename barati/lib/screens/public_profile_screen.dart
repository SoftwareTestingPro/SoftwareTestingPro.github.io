import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/logic_service.dart';

class PublicProfileScreen extends StatefulWidget {
  final BaratiUser user;

  const PublicProfileScreen({super.key, required this.user});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  bool _isHost = false;
  String? _currentUserId;
  List<BaratiEvent> _myEvents = [];
  List<RoleApplication> _userApplicationsToMyEvents = [];
  double? _guestRating;
  double? _hostRating;
  int _eventsHostedCount = 0;
  List<RoleApplication> _allApps = [];
  List<BaratiEvent> _allEvents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserInfo();
  }

  Future<void> _loadCurrentUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id') ?? prefs.getString('mobileNumber') ?? 'anonymous';
    final profile = await SupabaseService().getProfile(_currentUserId!);
    
    if (profile != null && profile.userRole == UserRole.host) {
      final events = await SupabaseService().getEvents();
      final allUserApps = await SupabaseService().getApplicationsForUser(widget.user.id);
      
      final now = DateTime.now();
      _myEvents = events.where((e) {
        final isOwner = e.hostId == _currentUserId;
        final isFuture = e.date.isAfter(now);
        final needsTheirRole = e.neededRoles.any((r) => widget.user.possibleRoles.contains(r.role));
        final alreadyInteracted = allUserApps.any((a) => a.eventId == e.id);
        return isOwner && isFuture && needsTheirRole && !alreadyInteracted;
      }).toList();
      
      _isHost = true;
    }
    
    _allApps = await SupabaseService().getAllApplications();
    _allEvents = await SupabaseService().getEvents();
    
    _guestRating = ReputationLogic.calculateGuestRating(widget.user.id, _allApps);
    _hostRating = ReputationLogic.calculateHostRating(widget.user.id, _allApps, _allEvents);
    _eventsHostedCount = ReputationLogic.countEventsHosted(widget.user.id, _allEvents);
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showInviteDialog() async {
    if (_myEvents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This user is already part of your events or matches no roles.')),
      );
      return;
    }

    BaratiEvent? selectedEvent;
    List<FamilyRole> selectedRoles = [];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Invite to Event', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<BaratiEvent>(
                  decoration: const InputDecoration(labelText: 'Select Event'),
                  items: _myEvents.map((e) => DropdownMenuItem(value: e, child: Text(e.title))).toList(),
                  onChanged: (val) {
                    setDialogState(() {
                      selectedEvent = val;
                      selectedRoles = [];
                    });
                  },
                ),
                if (selectedEvent != null) ...[
                  const SizedBox(height: 16),
                  Text('Select Roles:', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: selectedEvent!.neededRoles
                          .where((r) => EventRole.matchGender(widget.user.gender, r.gender))
                          .where((r) => widget.user.possibleRoles.contains(r.role))
                          .map((r) => CheckboxListTile(
                                title: Text(r.role.toLabel()),
                                value: selectedRoles.contains(r.role),
                                onChanged: (val) {
                                  setDialogState(() {
                                    if (val == true) {
                                      selectedRoles.add(r.role);
                                    } else {
                                      selectedRoles.remove(r.role);
                                    }
                                  });
                                },
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: (selectedEvent != null && selectedRoles.isNotEmpty)
                  ? () async {
                      for (var role in selectedRoles) {
                        final newApp = RoleApplication(
                          id: const Uuid().v4(),
                          eventId: selectedEvent!.id,
                          applicantId: widget.user.id,
                          appliedRole: role,
                          isInvitation: true,
                          status: ApplicationStatus.invitationPending,
                        );
                        await SupabaseService().applyForRole(newApp);
                      }
                      if (!mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invitations sent successfully!')),
                      );
                    }
                  : null,
              child: const Text('Send Invites'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = widget.user;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${user.name}\'s Profile', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 60,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                backgroundImage: user.profileImageUrl != null && user.profileImageUrl!.startsWith('http')
                  ? NetworkImage(user.profileImageUrl!) as ImageProvider
                  : user.profileImageUrl != null 
                    ? MemoryImage(base64Decode(user.profileImageUrl!)) 
                    : null,
                child: user.profileImageUrl == null 
                  ? Icon(Icons.person, size: 60, color: theme.colorScheme.primary)
                  : null,
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                user.name,
                style: GoogleFonts.playfairDisplay(fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ),
            Center(
              child: Text(
                '${user.age} years • ${user.gender}',
                style: GoogleFonts.montserrat(fontSize: 16, color: Colors.grey[600]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_guestRating != null) 
                  _buildStatBadge(
                    'Guest Rating', 
                    _guestRating!, 
                    Colors.amber,
                    onTap: () => _showReviewsSheet(isGuestReview: true),
                  ),
              ],
            ),
            if (_eventsHostedCount > 0) ...[
              const SizedBox(height: 12),
              Center(
                child: Column(
                  children: [
                    Text(
                      'Hosted $_eventsHostedCount ${_eventsHostedCount == 1 ? 'event' : 'events'}',
                      style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                    ),
                    if (_hostRating != null) ...[
                      const SizedBox(height: 8),
                      _buildStatBadge(
                        'Hosting Reputation', 
                        _hostRating!, 
                        Colors.deepPurple,
                        onTap: () => _showReviewsSheet(isGuestReview: false),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            
            _buildInfoSection(Icons.location_on, 'Location', '${user.city}, ${user.state}'),
            if (_isHost)
              _buildInfoSection(Icons.phone, 'Mobile Number', user.id), // user.id is the mobile number in this app
            _buildInfoSection(Icons.work, 'Profession', user.profession),
            _buildInfoSection(Icons.school, 'Education', user.education),
            _buildInfoSection(Icons.translate, 'Languages', user.languages.join(', ')),
            
            const SizedBox(height: 24),
            _buildLabel('About'),
            Text(
              user.bio,
              style: GoogleFonts.montserrat(fontSize: 16, height: 1.5),
            ),
            
            const SizedBox(height: 32),
            _buildLabel('Roles They Can Play'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: user.possibleRoles
                .where((role) => role.isValidForGender(user.gender))
                .map((role) => Chip(
                  label: Text(role.toLabel()),
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                )).toList(),
            ),
            const SizedBox(height: 40),
            if (_isHost && user.id != _currentUserId && _myEvents.isNotEmpty)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _showInviteDialog,
                  icon: const Icon(Icons.mail_outline),
                  label: Text('Request for Role', style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        label,
        style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black),
      ),
    );
  }

  Widget _buildStatBadge(String label, double rating, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              '${rating.toStringAsFixed(1)} $label',
              style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.bold, color: color),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios, size: 10, color: color),
            ],
          ],
        ),
      ),
    );
  }

  void _showReviewsSheet({required bool isGuestReview}) {
    final relevantApps = _allApps.where((app) {
      if (isGuestReview) {
        return app.applicantId == widget.user.id && app.hostRating != null;
      } else {
        final event = _allEvents.firstWhere((e) => e.id == app.eventId, orElse: () => _allEvents[0]);
        return event.hostId == widget.user.id && app.userRating != null;
      }
    }).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isGuestReview ? 'Guest Reviews' : 'Hosting Reviews',
              style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: relevantApps.isEmpty
                  ? Center(child: Text('No reviews yet.', style: GoogleFonts.montserrat(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: relevantApps.length,
                      itemBuilder: (context, index) {
                        final app = relevantApps[index];
                        final rating = isGuestReview ? app.hostRating : app.userRating;
                        final comment = isGuestReview ? app.hostComment : app.userComment;
                        final event = _allEvents.firstWhere((e) => e.id == app.eventId, orElse: () => _allEvents[0]);
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      event.title,
                                      style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Row(
                                    children: List.generate(5, (i) => Icon(
                                      Icons.star,
                                      size: 14,
                                      color: i < rating! ? Colors.amber : Colors.grey[300],
                                    )),
                                  ),
                                ],
                              ),
                              if (comment != null && comment.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '"$comment"',
                                  style: GoogleFonts.montserrat(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey[800]),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[600])),
              Text(value, style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}
