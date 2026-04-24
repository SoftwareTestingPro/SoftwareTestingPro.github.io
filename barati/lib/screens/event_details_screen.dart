import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

class EventDetailsScreen extends StatefulWidget {
  final BaratiEvent event;
  const EventDetailsScreen({super.key, required this.event});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  bool _hasApplied = false;
  BaratiUser? _currentUser;
  BaratiUser? _hostUser;
  bool _isLoading = true;

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
    final applied = await SupabaseService().hasApplied(widget.event.id, userId);
    
    if (mounted) {
      setState(() {
        _currentUser = profile;
        _hostUser = hostProfile;
        _hasApplied = applied;
        _isLoading = false;
      });
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

      setState(() => _hasApplied = true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Application sent successfully!')),
      );
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
                  _buildSectionTitle('Roles Needed'),
                  const SizedBox(height: 4),
                  Text(
                    'Apply for a role that matches your profile.',
                    style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  _buildRolesList(),
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
              '${widget.event.date.day}/${widget.event.date.month}/${widget.event.date.year}',
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
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildRolesList() {
    final filteredRoles = widget.event.neededRoles.where((roleInfo) {
      if (_currentUser == null) return true;
      
      // Gender check
      if (roleInfo.gender != 'Any' && roleInfo.gender.toLowerCase() != _currentUser!.gender.toLowerCase()) {
        return false;
      }
      
      // Role match check: Check if roleInfo.role exists in _currentUser.possibleRoles
      return _currentUser!.possibleRoles.contains(roleInfo.role);
    }).toList();

    if (filteredRoles.isEmpty) {
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
                  ElevatedButton(
                    onPressed: _hasApplied ? null : () => _applyForRole(roleInfo),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(_hasApplied ? 'Applied' : 'Apply'),
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
