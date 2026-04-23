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

  @override
  void initState() {
    super.initState();
    _checkApplicationStatus();
  }

  Future<void> _checkApplicationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('mobileNumber') ?? 'anonymous';
    
    // Check Supabase
    final applied = await SupabaseService().hasApplied(widget.event.id, userId);
    setState(() => _hasApplied = applied);
  }

  Future<void> _applyForRole(FamilyRole role) async {
    final messageController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Apply for ${role.name}', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
      final userId = prefs.getString('mobileNumber') ?? 'anonymous';
      
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
    final theme = Theme.of(context);
    
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
    if (widget.event.neededRoles.isEmpty) {
      return Text('No specific roles listed.', style: GoogleFonts.montserrat(color: Colors.grey));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: widget.event.neededRoles.length,
      itemBuilder: (context, index) {
        final role = widget.event.neededRoles[index];
        String label = role.name.replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}').toLowerCase();
        label = label[0].toUpperCase() + label.substring(1);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16)),
              ElevatedButton(
                onPressed: _hasApplied ? null : () => _applyForRole(role),
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
      case EventType.anniversary: color = Colors.purple; break;
      case EventType.death: color = Colors.black54; break;
      default: color = Colors.blue;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(
        type.name.toUpperCase(),
        style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
