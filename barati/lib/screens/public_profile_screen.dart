import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

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
    
    // Calculate Ratings and Stats
    final allApps = await SupabaseService().getAllApplications();
    final allEvents = await SupabaseService().getEvents();
    
    // 1. As a Barati (Guest): Average rating received from hosts
    final applicationsAsGuest = allApps.where((a) => a.applicantId == widget.user.id && a.hostRating != null).toList();
    if (applicationsAsGuest.isNotEmpty) {
      double total = 0;
      for (var app in applicationsAsGuest) {
        total += app.hostRating!;
      }
      _guestRating = total / applicationsAsGuest.length;
    }

    // 2. As a Host: Count events hosted and average rating received from guests
    final eventsHosted = allEvents.where((e) => e.hostId == widget.user.id).toList();
    _eventsHostedCount = eventsHosted.length;
    
    final eventIds = eventsHosted.map((e) => e.id).toSet();
    final applicationsToHostedEvents = allApps.where((a) => eventIds.contains(a.eventId) && a.userRating != null).toList();
    
    if (applicationsToHostedEvents.isNotEmpty) {
      double total = 0;
      for (var app in applicationsToHostedEvents) {
        total += app.userRating!;
      }
      _hostRating = total / applicationsToHostedEvents.length;
    }
    
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
    EventRole? selectedRole;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Invite to Event', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<BaratiEvent>(
                decoration: const InputDecoration(labelText: 'Select Event'),
                items: _myEvents.map((e) => DropdownMenuItem(value: e, child: Text(e.title))).toList(),
                onChanged: (val) {
                  setDialogState(() {
                    selectedEvent = val;
                    selectedRole = null;
                  });
                },
              ),
              if (selectedEvent != null) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<EventRole>(
                  decoration: const InputDecoration(labelText: 'Select Role'),
                  items: selectedEvent!.neededRoles
                      .where((r) => r.gender == 'Any' || r.gender.toLowerCase() == widget.user.gender.toLowerCase())
                      .where((r) => widget.user.possibleRoles.contains(r.role))
                      .map((r) => DropdownMenuItem(value: r, child: Text(r.role.toLabel()))).toList(),
                  onChanged: (val) => setDialogState(() => selectedRole = val),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: (selectedEvent != null && selectedRole != null)
                  ? () async {
                      final newApp = RoleApplication(
                        id: const Uuid().v4(),
                        eventId: selectedEvent!.id,
                        applicantId: widget.user.id,
                        appliedRole: selectedRole!.role,
                        isInvitation: true,
                        status: ApplicationStatus.invitationPending,
                      );
                      await SupabaseService().applyForRole(newApp);
                      if (!mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invitation sent successfully!')),
                      );
                    }
                  : null,
              child: const Text('Send Invite'),
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
                  _buildStatBadge('Barati Rating', _guestRating!, Colors.amber),
                if (_guestRating != null && _hostRating != null) const SizedBox(width: 8),
                if (_hostRating != null)
                  _buildStatBadge('Host Rating', _hostRating!, Colors.deepPurple),
              ],
            ),
            if (_eventsHostedCount > 0) ...[
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Hosted $_eventsHostedCount events',
                  style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[700]),
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

  Widget _buildStatBadge(String label, double rating, Color color) {
    return Container(
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
        ],
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
