import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/models.dart';
import 'profile_screen.dart';
import 'add_event_screen.dart';
import 'event_details_screen.dart';
import 'manage_applications_screen.dart';
import 'public_profile_screen.dart';
import '../services/supabase_service.dart';
import '../services/logic_service.dart';
import '../services/event_logic.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  UserRole _currentType = UserRole.host;
  List<BaratiEvent> _events = [];
  List<BaratiEvent> _filteredEvents = [];
  List<BaratiUser> _profiles = [];
  List<BaratiUser> _filteredProfiles = [];
  List<FamilyRole> _userRoles = [];
  List<RoleApplication> _userApplications = [];
  List<RoleApplication> _allApplications = [];
  int _eventsHostedCount = 0;
  bool _isLoading = true;
  String _firstName = 'User';
  String? _currentUserId;
  String? _userGender;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkProfile();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProfiles = _profiles.where((p) {
        final matchesName = p.name.toLowerCase().contains(query);
        final matchesRole = p.possibleRoles.any((r) => 
          r.isValidForGender(p.gender) && r.toLabel().toLowerCase().contains(query)
        );
        return matchesName || matchesRole;
      }).toList();
    });
  }

  Future<void> _checkProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final mobileNumber = prefs.getString('mobileNumber');
    
    if (mobileNumber != null) {
      final profile = await SupabaseService().getProfile(mobileNumber);
      if (profile == null) {
        // No cloud profile found, force setup
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        );
      } else {
        // Sync cloud data to local for UI convenience
        await prefs.setString('userName', profile.name);
        await prefs.setBool('hasProfile', true);
        if (mounted) {
          setState(() {
            _firstName = profile.name.split(' ')[0];
            _userRoles = profile.possibleRoles;
          });
        }
      }
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id') ?? prefs.getString('mobileNumber') ?? 'anonymous';
    final currentUserId = _currentUserId!;
    
    // Load Name
    final fullName = prefs.getString('userName') ?? 'User';
    if (mounted) {
      setState(() {
        _firstName = fullName.split(' ')[0];
      });
    }

    try {
      final cloudEvents = await SupabaseService().getEvents();
      final cloudProfiles = await SupabaseService().getProfiles();
      
      // Safety check: Find current user profile or create a temporary guest profile
      final currentProfile = cloudProfiles.where((p) => p.id == currentUserId).firstOrNull ?? 
          BaratiUser(
            id: currentUserId, 
            name: fullName, 
            age: 25, 
            gender: 'Other', 
            userRole: UserRole.baratiMember, 
            bio: '',
            possibleRoles: []
          );
      
      final userApps = await SupabaseService().getApplicationsForUser(currentUserId);
      final allApps = await SupabaseService().getAllApplications();

      if (mounted) {
        setState(() {
          _events = cloudEvents;
          _userRoles = currentProfile.possibleRoles;
          _userGender = currentProfile.gender;
          _profiles = cloudProfiles.where((p) => p.id != currentUserId).toList();
          _filteredProfiles = _profiles;
          _userApplications = userApps;
          _allApplications = allApps;
          
          // Apply initial filtering
          if (_currentType == UserRole.host) {
            _filteredEvents = _events.where((e) => e.hostId == currentUserId).toList();
          } else {
            _filteredEvents = _events.where((event) => 
              event.hostId != currentUserId // Show all events in discovery
            ).toList();
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading home data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadEvents() => _loadData();

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search for roles or people...',
          prefixIcon: const Icon(Icons.search, size: 20),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildAvailableBaratiList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    
    if (_filteredProfiles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text('No matching family members found.', style: GoogleFonts.montserrat(color: Colors.grey)),
        ),
      );
    }

    return SizedBox(
      height: 180,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: _filteredProfiles.length,
        itemBuilder: (context, index) {
          final profile = _filteredProfiles[index];
          String rolesLabel = profile.possibleRoles
              .where((r) => r.isValidForGender(profile.gender))
              .take(2)
              .map((r) => r.toLabel())
              .join(', ');
          if (profile.possibleRoles.where((r) => r.isValidForGender(profile.gender)).length > 2) rolesLabel += '...';

          return GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PublicProfileScreen(user: profile),
                ),
              );
            },
            child: Container(
              width: 140,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    backgroundImage: profile.profileImageUrl != null && profile.profileImageUrl!.startsWith('http')
                      ? NetworkImage(profile.profileImageUrl!) as ImageProvider
                      : profile.profileImageUrl != null 
                        ? MemoryImage(base64Decode(profile.profileImageUrl!)) 
                        : null,
                    child: profile.profileImageUrl == null 
                      ? Icon(Icons.person, size: 40, color: Theme.of(context).colorScheme.primary) 
                      : null,
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      profile.name, 
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 13),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      rolesLabel, 
                      style: GoogleFonts.montserrat(fontSize: 11, color: Colors.grey),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildUserRating(profile.id),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserRating(String userId) {
    final avg = ReputationLogic.calculateGuestRating(userId, _allApplications);
    
    if (avg == null) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.star, size: 12, color: Colors.amber),
        const SizedBox(width: 2),
        Text(
          avg.toStringAsFixed(1),
          style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  if (_currentType == UserRole.host) ...[
                    _buildSectionHeader(context, 'Find Your Family'),
                    _buildSearchBar(),
                    const SizedBox(height: 16),
                    _buildAvailableBaratiList(),
                    const SizedBox(height: 32),
                    _buildHostDashboard(),
                  ] else ...[
                    _buildSectionHeader(context, 'Events Near You', 'Map'),
                    const SizedBox(height: 16),
                    _buildWeddingEventsList(),
                    const SizedBox(height: 32),
                    _buildSectionHeader(context, 'Active Applications', 'History'),
                    const SizedBox(height: 16),
                    _buildMyApplicationsList(isPast: false),
                    const SizedBox(height: 32),
                    _buildSectionHeader(context, 'Attended Events', 'History'),
                    const SizedBox(height: 16),
                    _buildMyApplicationsList(isPast: true),
                  ],
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(theme),
    );
  }

  Widget _buildRoleToggle(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildToggleButton('Host', UserRole.host),
            _buildToggleButton('Be a Barati', UserRole.baratiMember),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton(String label, UserRole type) {
    bool isSelected = _currentType == type;
    return GestureDetector(
      onTap: () async {
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('user_id') ?? prefs.getString('mobileNumber') ?? 'anonymous';
        
        setState(() {
          _currentType = type;
          if (_currentType == UserRole.host) {
            _filteredEvents = _events.where((e) => e.hostId == userId).toList();
          } else {
            _filteredEvents = _events.where((event) => 
              event.hostId != userId // Show all events in discovery
            ).toList();
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Text(
          label,
          style: GoogleFonts.montserrat(
            color: isSelected ? Colors.white : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 300.0,
      pinned: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: () => _logout(context),
          tooltip: 'Logout',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: LayoutBuilder(
          builder: (context, constraints) {
            // Only show the subtitle when expanded
            final bool isExpanded = constraints.maxHeight > 150;
            return Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isExpanded)
                  Text(
                    'Welcome, $_firstName',
                    style: GoogleFonts.montserrat(fontSize: 14, color: Colors.white70),
                  ),
                Text(
                  'Barati',
                  style: GoogleFonts.playfairDisplay(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: isExpanded ? 32 : 20,
                    shadows: [const Shadow(blurRadius: 10, color: Colors.black45, offset: Offset(2, 2))],
                  ),
                ),
                if (isExpanded) const SizedBox(height: 60),
              ],
            );
          },
        ),
        centerTitle: true,
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/hero_bg.png', fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black26, Colors.transparent, Colors.black87],
                ),
              ),
            ),
            Positioned(
              bottom: 110,
              left: 20,
              right: 20,
              child: Text(
                _currentType == UserRole.host 
                  ? 'Build your support system for the big day.' 
                  : 'Be the family someone needs.',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, [String? action]) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          if (action != null)
            TextButton(onPressed: () {}, child: Text(action, style: GoogleFonts.montserrat(color: const Color(0xFFD4AF37), fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildWeddingEventsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final now = DateTime.now();
    final futureEvents = _filteredEvents.where((e) => e.date.isAfter(now)).toList();

    if (futureEvents.isEmpty) {
      return Container(
        height: 200,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                'No events found.',
                style: GoogleFonts.montserrat(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: futureEvents.length,
        itemBuilder: (context, index) {
          final event = futureEvents[index];
          return GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => EventDetailsScreen(event: event)),
            ).then((_) => _loadData()),
            child: Container(
              width: 280,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: event.imageUrl.startsWith('http') 
                                ? NetworkImage(event.imageUrl) as ImageProvider
                                : MemoryImage(base64Decode(event.imageUrl)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.title,
                              style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            _eventTypeBadge(event.eventType),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.city.isNotEmpty && event.city != 'City' 
                              ? '${event.city}, ${event.state}' 
                              : (event.state.isNotEmpty && event.state != 'State' ? event.state : 'Location not set'),
                          style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[600]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        EventLogic.formatDateTime(event.date),
                        style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${event.neededRoles.length} Roles Needed',
                        style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                      ),
                      if (event.neededRoles.any((r) => 
                        _userRoles.contains(r.role) && 
                        EventRole.matchGender(_userGender ?? 'Other', r.gender)
                      ))
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'MATCH',
                            style: GoogleFonts.montserrat(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMyApplicationsList({bool isPast = false}) {
    final now = DateTime.now();
    
    final filteredApps = _userApplications.where((app) {
      final event = _events.firstWhere((e) => e.id == app.eventId, orElse: () => _events[0]);
      if (isPast) {
        // Attended events: past and approved
        return event.date.isBefore(now) && app.isApproved;
      } else {
        // Active applications: 
        // 1. Future events (any status)
        // 2. Past events that were approved (Wait, no, those are in 'Attended')
        // 3. Past events where application is pending/invitation is pending? No, those should be expired.
        
        // Only show future events in active applications, 
        // OR past events if they were approved (but wait, that's what 'isPast' true handles).
        // Actually, let's keep it simple: Active = Future events only, 
        // or specifically pending things for future events.
        
        if (event.date.isBefore(now)) {
          // If event is past, only show it in 'Active' if it was NOT approved but we want to show history?
          // No, usually 'Active' means things you can still act upon or are waiting for.
          return false; 
        }
        return true;
      }
    }).toList();

    if (filteredApps.isEmpty) {
      return Container(
        height: 120,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Center(
          child: Text(isPast ? 'No attended events yet.' : 'No active applications.', style: GoogleFonts.montserrat(color: Colors.grey)),
        ),
      );
    }

    final Map<String, List<RoleApplication>> groupedApps = {};
    for (var app in filteredApps) {
      groupedApps.putIfAbsent(app.eventId, () => []).add(app);
    }

    return SizedBox(
      height: 180,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: groupedApps.length,
        itemBuilder: (context, index) {
          final eventId = groupedApps.keys.elementAt(index);
          final apps = groupedApps[eventId]!;
          final event = _events.firstWhere((e) => e.id == eventId, orElse: () => _events[0]);

          return GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => EventDetailsScreen(event: event)),
              );
            },
            child: Container(
              width: 280,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text('Applied Roles:', style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 4),
                  Expanded(
                    child: ListView.builder(
                      itemCount: apps.length,
                      itemBuilder: (context, i) {
                        final app = apps[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Row(
                            children: [
                              Icon(
                                app.isApproved ? Icons.check_circle : Icons.pending,
                                size: 14,
                                color: app.isApproved ? Colors.green : Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  app.appliedRole.toLabel(),
                                  style: GoogleFonts.montserrat(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                _getStatusText(app),
                                style: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusColor(app),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  if (apps.any((a) => a.isInvitation && a.status == ApplicationStatus.invitationPending))
                    Builder(
                      builder: (context) {
                        final isEventPast = event.date.isBefore(DateTime.now());
                        if (isEventPast) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'Invitation Expired',
                                style: GoogleFonts.montserrat(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          );
                        }
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () async {
                                final invite = apps.firstWhere((a) => a.isInvitation && a.status == ApplicationStatus.invitationPending);
                                await SupabaseService().respondToInvitation(invite.id, false, invite.eventId, invite.applicantId);
                                _loadData();
                              },
                              child: const Text('Deny', style: TextStyle(color: Colors.red)),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                final invite = apps.firstWhere((a) => a.isInvitation && a.status == ApplicationStatus.invitationPending);
                                await SupabaseService().respondToInvitation(invite.id, true, invite.eventId, invite.applicantId);
                                _loadData();
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                              child: const Text('Accept'),
                            ),
                          ],
                        );
                      }
                    )
                  else if (!isPast && apps.any((a) => a.status != ApplicationStatus.declined && a.status != ApplicationStatus.withdrawn))
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          final app = apps.firstWhere((a) => a.status != ApplicationStatus.declined && a.status != ApplicationStatus.withdrawn);
                          await SupabaseService().cancelApplication(app.id, app.eventId, app.applicantId);
                          _loadData();
                        },
                        icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                        label: const Text('Withdraw', style: TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(
        type.name.replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}').toUpperCase(),
        style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _roleBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: GoogleFonts.montserrat(fontSize: 10)),
    );
  }

  Widget _buildMyPossibleRoles(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _userRoles.map((r) => Chip(
          label: Text(r.toLabel()),
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        )).toList(),
      ),
    );
  }

  Widget _buildBottomNav(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) async {
          if (index == 2) {
            // Action Button (Create Event)
            final result = await Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const AddEventScreen()),
            );
            if (result == true) {
              _loadData();
            }
            return;
          }
          
          if (index == 4) {
            // Profile
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const ProfileScreen(isEditMode: true)),
            );
            _loadData();
            return;
          }

          setState(() {
            _selectedIndex = index;
            if (index == 0) {
              _currentType = UserRole.host;
            } else if (index == 1) {
              _currentType = UserRole.baratiMember;
            }
            
            // Refresh filtered events based on new type
            if (_currentUserId != null) {
              if (_currentType == UserRole.host) {
                _filteredEvents = _events.where((e) => e.hostId == _currentUserId).toList();
              } else {
                _filteredEvents = _events.where((e) => e.hostId != _currentUserId).toList();
              }
            }
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.bold),
        unselectedLabelStyle: GoogleFonts.montserrat(fontSize: 10),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Host'),
          BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), activeIcon: Icon(Icons.explore), label: 'Discover'),
          BottomNavigationBarItem(
            icon: CircleAvatar(
              radius: 20,
              backgroundColor: Color(0xFF8B0000),
              child: Icon(Icons.add, color: Colors.white),
            ),
            label: 'Create',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_outlined), activeIcon: Icon(Icons.notifications), label: 'Activity'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
    // We keep mobileNumber, events, and profile data so they persist across logins
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
  }

  String _getStatusText(RoleApplication app) {
    if (app.isInvitation) {
      if (app.status == ApplicationStatus.invitationPending) return 'Invitation';
      if (app.status == ApplicationStatus.invitationAccepted) return 'Accepted';
      if (app.status == ApplicationStatus.invitationDeclined) return 'Declined';
    }
    
    if (app.isApproved) return 'Approved';
    if (app.status == ApplicationStatus.declined) return 'Declined';
    if (app.status == ApplicationStatus.withdrawn) return 'Withdrawn';
    
    return 'Pending';
  }

  Color _getStatusColor(RoleApplication app) {
    if (app.isInvitation && app.status == ApplicationStatus.invitationPending) return Colors.blue;
    if (app.isApproved || app.status == ApplicationStatus.invitationAccepted) return Colors.green;
    if (app.status == ApplicationStatus.declined || app.status == ApplicationStatus.invitationDeclined) return Colors.red;
    if (app.status == ApplicationStatus.withdrawn) return Colors.grey;
    return Colors.orange;
  }

  Widget _buildHostDashboard() {
    if (_currentUserId == null) return const SizedBox.shrink();
    
    final futureEvents = EventLogic.filterHostEvents(_events, _currentUserId!, isPast: false);
    final pastEvents = EventLogic.filterHostEvents(_events, _currentUserId!, isPast: true);

    // Calculate host overall rating
    final hostAvg = ReputationLogic.calculateHostRating(_currentUserId!, _allApplications, _events);
    _eventsHostedCount = ReputationLogic.countEventsHosted(_currentUserId!, _events);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        if (futureEvents.isNotEmpty) ...[
          _buildSectionHeader(context, 'My Upcoming Events', 'View All'),
          const SizedBox(height: 16),
          _buildEventsList(futureEvents, isHost: true),
        ],
        if (pastEvents.isNotEmpty) ...[
          const SizedBox(height: 32),
          _buildSectionHeader(context, 'My Past Events', 'History'),
          const SizedBox(height: 16),
          _buildEventsList(pastEvents, isHost: true, isPast: true),
        ],
        if (_filteredEvents.isEmpty)
          _buildEmptyState('No events found. Start by creating one!', Icons.add_circle_outline),
      ],
    );
  }

  Widget _buildEventsList(List<BaratiEvent> events, {bool isHost = false, bool isPast = false}) {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          final isOwner = isHost;

          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => EventDetailsScreen(event: event)),
            ).then((_) => _loadData()),
            child: Container(
              width: 280,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: event.imageUrl.startsWith('http') 
                                ? NetworkImage(event.imageUrl) as ImageProvider
                                : MemoryImage(base64Decode(event.imageUrl)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.title,
                              style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            _eventTypeBadge(event.eventType),
                          ],
                        ),
                      ),
                      if (isOwner && !isPast)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => AddEventScreen(eventToEdit: event)),
                                );
                                if (result == true) _loadData();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Event'),
                                    content: const Text('Are you sure you want to delete this event?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await SupabaseService().deleteEvent(event.id);
                                  _loadData();
                                }
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${event.city}, ${event.state}',
                          style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[600]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        EventLogic.formatDate(event.date),
                        style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${event.neededRoles.length} Roles Needed',
                        style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                      ),
                      if (isOwner && !isPast)
                        Text(
                          '${event.approvedMemberIds.length} Joined',
                          style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green),
                        ),
                      if (isPast) 
                        Builder(
                          builder: (context) {
                            final avg = ReputationLogic.calculateEventRating(event.id, _allApplications);
                            if (avg == null) return const SizedBox.shrink();
                            return Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  avg.toStringAsFixed(1),
                                  style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber[900]),
                                ),
                              ],
                            );
                          }
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(40),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center, style: GoogleFonts.montserrat(color: Colors.grey[500])),
        ],
      ),
    );
  }
}
