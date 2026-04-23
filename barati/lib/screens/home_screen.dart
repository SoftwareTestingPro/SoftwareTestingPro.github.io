import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  UserRole _currentType = UserRole.brideGroom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
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
                  _buildRoleToggle(context),
                  const SizedBox(height: 32),
                  if (_currentType == UserRole.brideGroom) ...[
                    _buildSectionHeader(context, 'Find Your Family', 'Search'),
                    const SizedBox(height: 16),
                    _buildAvailableBaratiList(),
                    const SizedBox(height: 32),
                    _buildSectionHeader(context, 'Needed for Rituals', 'View All'),
                    const SizedBox(height: 16),
                    _buildRitualRolesGrid(context),
                  ] else ...[
                    _buildSectionHeader(context, 'Weddings Near You', 'Map'),
                    const SizedBox(height: 16),
                    _buildWeddingEventsList(),
                    const SizedBox(height: 32),
                    _buildSectionHeader(context, 'Roles You Can Play', 'Edit'),
                    const SizedBox(height: 16),
                    _buildMyPossibleRoles(context),
                  ],
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(theme),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: theme.colorScheme.primary,
        icon: Icon(_currentType == UserRole.brideGroom ? Icons.add : Icons.search, color: Colors.white),
        label: Text(
          _currentType == UserRole.brideGroom ? 'Create Wedding Event' : 'Find a Family',
          style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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
            _buildToggleButton('Bride/Groom', UserRole.brideGroom),
            _buildToggleButton('Be a Barati', UserRole.baratiMember),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton(String label, UserRole type) {
    bool isSelected = _currentType == type;
    return GestureDetector(
      onTap: () => setState(() => _currentType = type),
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
        title: Text(
          'Barati',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 28,
            shadows: [const Shadow(blurRadius: 10, color: Colors.black45, offset: Offset(2, 2))],
          ),
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
              bottom: 40,
              left: 20,
              right: 20,
              child: Text(
                _currentType == UserRole.brideGroom 
                  ? 'Build your support system for the big day.' 
                  : 'Be the family someone needs.',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, String action) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          TextButton(onPressed: () {}, child: Text(action, style: GoogleFonts.montserrat(color: const Color(0xFFD4AF37), fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildAvailableBaratiList() {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        itemBuilder: (context, index) {
          final names = ['Rahul S.', 'Priya M.', 'Amit K.', 'Suman V.', 'Vikram R.'];
          final roles = ['Elder Brother', 'Sister', 'Uncle', 'Motherly Figure', 'Best Man'];
          return Container(
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
                  child: Icon(Icons.person, size: 40, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: 12),
                Text(names[index], style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
                Text(roles[index], style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRitualRolesGrid(BuildContext context) {
    final roles = [
      {'name': 'Kanyadaan (Father)', 'icon': Icons.favorite, 'color': Colors.red},
      {'name': 'Haldi Sisters', 'icon': Icons.auto_awesome, 'color': Colors.orange},
      {'name': 'Bhai ka Support', 'icon': Icons.security, 'color': Colors.blue},
      {'name': 'Blessings (Elders)', 'icon': Icons.volunteer_activism, 'color': Colors.purple},
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.5,
        ),
        itemCount: roles.length,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: (roles[index]['color'] as Color).withOpacity(0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(roles[index]['icon'] as IconData, color: roles[index]['color'] as Color),
                const SizedBox(width: 8),
                Expanded(child: Text(roles[index]['name'] as String, style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold))),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWeddingEventsList() {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        itemBuilder: (context, index) {
          final titles = ['Aman\'s Wedding', 'Neha\'s Sangeet', 'Sameer\'s Haldi'];
          return Container(
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(titles[index], style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18)),
                    const Icon(Icons.favorite, color: Colors.red, size: 20),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Location: Delhi, India', style: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey)),
                const Spacer(),
                Text('Roles Needed:', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _roleBadge('Father'),
                    const SizedBox(width: 4),
                    _roleBadge('Sister'),
                    const SizedBox(width: 4),
                    Text('+2 more', style: GoogleFonts.montserrat(fontSize: 10, color: Colors.blue)),
                  ],
                ),
              ],
            ),
          );
        },
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
    final roles = ['Brother', 'Best Friend', 'Uncle', 'Cousin'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: roles.map((r) => Chip(
          label: Text(r),
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        )).toList(),
      ),
    );
  }

  Widget _buildBottomNav(ThemeData theme) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 12,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(icon: Icon(Icons.home, color: _selectedIndex == 0 ? theme.colorScheme.primary : Colors.grey), onPressed: () => setState(() => _selectedIndex = 0)),
            IconButton(icon: Icon(Icons.people, color: _selectedIndex == 1 ? theme.colorScheme.primary : Colors.grey), onPressed: () => setState(() => _selectedIndex = 1)),
            const SizedBox(width: 40),
            IconButton(icon: Icon(Icons.notifications_none, color: _selectedIndex == 2 ? theme.colorScheme.primary : Colors.grey), onPressed: () => setState(() => _selectedIndex = 2)),
            IconButton(
              icon: Icon(Icons.person_outline, color: _selectedIndex == 3 ? theme.colorScheme.primary : Colors.grey),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const ProfileScreen(isEditMode: true)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
  }
}
