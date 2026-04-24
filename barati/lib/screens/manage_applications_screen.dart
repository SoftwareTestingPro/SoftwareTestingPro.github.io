import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/models.dart';
import 'public_profile_screen.dart';
import '../services/supabase_service.dart';

class ManageApplicationsScreen extends StatefulWidget {
  final BaratiEvent event;
  const ManageApplicationsScreen({super.key, required this.event});

  @override
  State<ManageApplicationsScreen> createState() => _ManageApplicationsScreenState();
}

class _ManageApplicationsScreenState extends State<ManageApplicationsScreen> {
  List<RoleApplication> _applications = [];
  Map<String, BaratiUser> _applicantProfiles = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() => _isLoading = true);
    
    // Load from Supabase
    try {
      final cloudApps = await SupabaseService().getApplicationsForEvent(widget.event.id);
      
      // Fetch all user profiles to show names/images
      final allProfiles = await SupabaseService().getProfiles();
      final Map<String, BaratiUser> profileMap = {
        for (var p in allProfiles) p.id: p
      };

      setState(() {
        _applications = cloudApps;
        _applicantProfiles = profileMap;
        _isLoading = false;
      });
    } catch (e) {
      // Fallback to local
      final prefs = await SharedPreferences.getInstance();
      final appsJson = prefs.getString('applications') ?? '[]';
      final List<dynamic> appsList = json.decode(appsJson);
      setState(() {
        _applications = appsList
            .map((app) => RoleApplication.fromJson(app))
            .where((app) => app.eventId == widget.event.id)
            .toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _approveApplication(RoleApplication app) async {
    // Approve in Supabase
    await SupabaseService().approveApplication(app.id, app.eventId, app.applicantId);
    
    // Sync local (optional fallback)
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Update applications list (set isApproved to true)
    final appsJson = prefs.getString('applications') ?? '[]';
    List<dynamic> appsList = json.decode(appsJson);
    for (var i = 0; i < appsList.length; i++) {
      if (appsList[i]['id'] == app.id) {
        appsList[i]['isApproved'] = true;
        break;
      }
    }
    await prefs.setString('applications', json.encode(appsList));

    // 2. Update event's approvedMemberIds
    final eventsJson = prefs.getString('events') ?? '[]';
    List<dynamic> eventsList = json.decode(eventsJson);
    for (var i = 0; i < eventsList.length; i++) {
      if (eventsList[i]['id'] == widget.event.id) {
        List<String> approved = List<String>.from(eventsList[i]['approvedMemberIds']);
        if (!approved.contains(app.applicantId)) {
          approved.add(app.applicantId);
          eventsList[i]['approvedMemberIds'] = approved;
        }
        break;
      }
    }
    await prefs.setString('events', json.encode(eventsList));

    _loadApplications();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Application approved!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Applications', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _applications.isEmpty
              ? _buildEmptyState()
              : _buildApplicationsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_ind_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No applications yet.',
            style: GoogleFonts.montserrat(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _applications.length,
      itemBuilder: (context, index) {
        final app = _applications[index];
        final applicant = _applicantProfiles[app.applicantId];
        String roleLabel = app.appliedRole.toLabel();

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  if (applicant != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => PublicProfileScreen(user: applicant),
                      ),
                    );
                  }
                },
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      backgroundImage: applicant?.profileImageUrl != null && applicant!.profileImageUrl!.startsWith('http')
                          ? NetworkImage(applicant.profileImageUrl!) as ImageProvider
                          : (applicant?.profileImageUrl != null
                              ? MemoryImage(base64Decode(applicant!.profileImageUrl!))
                              : null),
                      child: applicant?.profileImageUrl == null
                          ? Icon(Icons.person, color: Theme.of(context).colorScheme.primary)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            applicant?.name ?? 'Applicant: ${app.applicantId}',
                            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            'Applied for: $roleLabel',
                            style: GoogleFonts.montserrat(color: Colors.grey[600], fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Divider(),
              ),
              Text(
                'Message:',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                app.message.isEmpty ? 'No message provided.' : app.message,
                style: GoogleFonts.montserrat(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {}, // Not implemented yet
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Colors.red),
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: app.isApproved ? null : () => _approveApplication(app),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(app.isApproved ? 'Approved' : 'Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
