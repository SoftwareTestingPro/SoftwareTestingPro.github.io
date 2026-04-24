import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import '../models/models.dart';

class PublicProfileScreen extends StatelessWidget {
  final BaratiUser user;

  const PublicProfileScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${user.name}\'s Profile', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
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
            const SizedBox(height: 32),
            
            _buildInfoSection(Icons.location_on, 'Location', '${user.city}, ${user.state}'),
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
              children: user.possibleRoles.map((role) => Chip(
                label: Text(role.toLabel()),
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              )).toList(),
            ),
            const SizedBox(height: 40),
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
