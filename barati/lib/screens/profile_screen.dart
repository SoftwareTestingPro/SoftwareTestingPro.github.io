import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'home_screen.dart';
import '../services/supabase_service.dart';
import '../models/models.dart';

class ProfileScreen extends StatefulWidget {
  final bool isEditMode;
  const ProfileScreen({super.key, this.isEditMode = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _cityController = TextEditingController();
  final _professionController = TextEditingController();
  
  static const List<String> _cityOptions = [
    'Mumbai', 'Delhi', 'Bangalore', 'Hyderabad', 'Ahmedabad', 'Chennai', 'Kolkata', 
    'Surat', 'Pune', 'Jaipur', 'Lucknow', 'Kanpur', 'Nagpur', 'Indore', 'Thane', 
    'Bhopal', 'Visakhapatnam', 'Pimpri-Chinchwad', 'Patna', 'Vadodara', 'Ghaziabad', 
    'Ludhiana', 'Agra', 'Nashik', 'Ranchi', 'Faridabad', 'Meerut', 'Rajkot', 
    'Kalyan-Dombivli', 'Vasai-Virar', 'Varanasi', 'Srinagar', 'Aurangabad', 
    'Dhanbad', 'Amritsar', 'Navi Mumbai', 'Allahabad', 'Howrah', 'Gwalior', 
    'Jabalpur', 'Coimbatore', 'Vijayawada', 'Jodhpur', 'Madurai', 'Raipur', 
    'Kota', 'Guwahati', 'Chandigarh', 'Solapur', 'Hubli-Dharwad', 'Bareilly', 
    'Moradabad', 'Mysore', 'Gurgaon', 'Aligarh', 'Jalandhar', 'Tiruchirappalli', 
    'Bhubaneswar', 'Salem', 'Mira-Bhayandar', 'Warangal', 'Guntur', 'Bhiwandi', 
    'Saharanpur', 'Gorakhpur', 'Bikaner', 'Amravati', 'Noida', 'Jamshedpur', 
    'Bhilai', 'Cuttack', 'Firozabad', 'Kochi', 'Nellore', 'Bhavnagar', 'Dehradun', 
    'Durgapur', 'Asansol', 'Rourkela', 'Nanded', 'Kolhapur', 'Ajmer', 'Akola', 
    'Gulbarga', 'Jamnagar', 'Ujjain', 'Loni', 'Siliguri', 'Jhansi', 'Ulhasnagar', 
    'Jammu', 'Sangli-Miraj & Kupwad', 'Mangalore', 'Erode', 'Belgaum', 'Ambattur', 
    'Tirunelveli', 'Malegaon', 'Gaya', 'Jalgaon', 'Udaipur', 'Maheshtala',
    'Unnao', 'Rae Bareli', 'Sitapur', 'Harda', 'Vidisha', 'Rewa', 'Satna', 
    'Muzaffarpur', 'Bhagalpur', 'Gaya', 'Arrah', 'Begusarai', 'Katihar',
    'Rohtak', 'Hisar', 'Panipat', 'Karnal', 'Sonipat', 'Ambala', 'Yamunanagar'
  ];
  
  String _selectedGender = 'Male';
  int _age = 25;
  String? _base64Image;
  List<String> _selectedRoles = [];
  bool _isLoading = true;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('userName') ?? '';
      _bioController.text = prefs.getString('userBio') ?? '';
      _cityController.text = prefs.getString('userCity') ?? '';
      _professionController.text = prefs.getString('userProfession') ?? '';
      _base64Image = prefs.getString('userImageBase64');
      _selectedGender = prefs.getString('userGender') ?? 'Male';
      _age = prefs.getInt('userAge') ?? 25;
      _selectedRoles = prefs.getStringList('userRoles') ?? [];
      _isLoading = false;
    });
  }

  List<String> _getRolesForGender(String gender) {
    List<String> common = ['Friend', 'Best Friend', 'Cousin', 'Colleague'];
    if (gender == 'Male') {
      return [
        ...common,
        'Boyfriend',
        'Ex-Boyfriend',
        'Husband',
        'Father-in-law',
        'Brother-in-law',
        'Father',
        'Brother',
        'Uncle',
        'Grandfather',
        'Best Man',
      ];
    } else if (gender == 'Female') {
      return [
        ...common,
        'Girlfriend',
        'Ex-Girlfriend',
        'Wife',
        'Mother-in-law',
        'Sister-in-law',
        'Mother',
        'Sister',
        'Aunt',
        'Grandmother',
        'Maid of Honor',
      ];
    }
    return common;
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _base64Image = base64Encode(bytes);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', _nameController.text);
    await prefs.setString('userBio', _bioController.text);
    await prefs.setString('userCity', _cityController.text);
    await prefs.setString('userProfession', _professionController.text);
    if (_base64Image != null) await prefs.setString('userImageBase64', _base64Image!);
    await prefs.setString('userGender', _selectedGender);
    await prefs.setInt('userAge', _age);
    await prefs.setStringList('userRoles', _selectedRoles);
    await prefs.setBool('hasProfile', true);

    // Save to Supabase
    final mobileNumber = prefs.getString('mobileNumber') ?? 'unknown';
    final user = BaratiUser(
      id: mobileNumber,
      name: _nameController.text,
      age: _age,
      gender: _selectedGender,
      userRole: UserRole.host, // Default, can be adjusted
      possibleRoles: _selectedRoles.map((r) {
        // Map string back to enum (simple contains check for now)
        return FamilyRole.values.firstWhere((e) => e.name.toLowerCase() == r.toLowerCase().replaceAll(' ', ''), orElse: () => FamilyRole.other);
      }).toList(),
      bio: _bioController.text,
      profileImageUrl: _base64Image, // We use base64 for now as it's small, ideally upload to storage
    );
    
    await SupabaseService().upsertProfile(user);

    if (!mounted) return;

    if (widget.isEditMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final availableRoles = _getRolesForGender(_selectedGender);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditMode ? 'Edit Profile' : 'Create Your Profile', 
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('isLoggedIn');
              if (!mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    backgroundImage: _base64Image != null 
                      ? MemoryImage(base64Decode(_base64Image!)) 
                      : null,
                    child: _base64Image == null 
                      ? Icon(Icons.person, size: 60, color: theme.colorScheme.primary)
                      : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: theme.colorScheme.primary,
                        child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildLabel('Full Name'),
            _buildTextField(controller: _nameController, hint: 'e.g. Rahul Sharma', icon: Icons.person_outline),
            const SizedBox(height: 20),
            _buildLabel('City'),
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<String>.empty();
                }
                return _cityOptions.where((String option) {
                  return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                });
              },
              onSelected: (String selection) {
                _cityController.text = selection;
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                // Sync the autocomplete controller with our persistence controller
                if (_cityController.text.isNotEmpty && controller.text.isEmpty) {
                  controller.text = _cityController.text;
                }
                controller.addListener(() {
                  _cityController.text = controller.text;
                });
                return _buildTextField(
                  controller: controller,
                  focusNode: focusNode,
                  hint: 'e.g. New Delhi',
                  icon: Icons.location_city,
                );
              },
            ),
            const SizedBox(height: 20),
            _buildLabel('Profession'),
            _buildTextField(controller: _professionController, hint: 'e.g. Software Engineer', icon: Icons.work_outline),
            const SizedBox(height: 20),
            _buildLabel('Gender'),
            Row(
              children: [
                _buildGenderChip('Male'),
                const SizedBox(width: 12),
                _buildGenderChip('Female'),
                const SizedBox(width: 12),
                _buildGenderChip('Other'),
              ],
            ),
            const SizedBox(height: 20),
            _buildLabel('Age'),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _age.toDouble(),
                    min: 18,
                    max: 100,
                    divisions: 82,
                    label: _age.toString(),
                    onChanged: (val) => setState(() => _age = val.toInt()),
                  ),
                ),
                Text('$_age years', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            _buildLabel('Roles You Can Play'),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: availableRoles.length,
                itemBuilder: (context, index) {
                  final role = availableRoles[index];
                  return CheckboxListTile(
                    title: Text(role, style: GoogleFonts.montserrat(fontSize: 14)),
                    value: _selectedRoles.contains(role),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedRoles.add(role);
                        } else {
                          _selectedRoles.remove(role);
                        }
                      });
                    },
                    activeColor: theme.colorScheme.primary,
                    dense: true,
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            _buildLabel('Short Bio'),
            _buildTextField(
              controller: _bioController,
              hint: 'Tell us a bit about yourself...',
              maxLines: 3,
              icon: Icons.notes,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(widget.isEditMode ? 'Update Profile' : 'Complete Profile', 
                  style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold)),
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
        style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller, 
    required String hint, 
    int maxLines = 1,
    IconData? icon,
    FocusNode? focusNode,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      maxLines: maxLines,
      decoration: InputDecoration(
        prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
        hintText: hint,
        hintStyle: GoogleFonts.montserrat(color: Colors.grey),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
      ),
    );
  }

  Widget _buildGenderChip(String gender) {
    final isSelected = _selectedGender == gender;
    return ChoiceChip(
      label: Text(gender),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() {
            _selectedGender = gender;
            // Clear roles that might not be valid for the new gender
            // (Keep common roles, remove specific ones)
            // But for simplicity, we'll just let the user re-select if they change gender
          });
        }
      },
      selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
      labelStyle: GoogleFonts.montserrat(
        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
