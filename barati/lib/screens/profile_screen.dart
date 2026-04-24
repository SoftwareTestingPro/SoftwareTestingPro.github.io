import 'package:flutter/material.dart';
import 'package:csc_picker_plus/csc_picker_plus.dart';
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
  final _stateController = TextEditingController();
  final _professionController = TextEditingController();
  final _educationController = TextEditingController();
  final _languagesController = TextEditingController();
  String _mobileNumber = '';
  
  String _selectedCountry = 'India';
  String _selectedState = '';
  String _selectedCity = '';
  
  String _selectedGender = 'Male';
  int _age = 25;
  String? _base64Image;
  List<String> _selectedRoles = [];
  UserRole _currentUserRole = UserRole.host;
  bool _isLoading = true;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _professionController.dispose();
    _educationController.dispose();
    _languagesController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    _mobileNumber = prefs.getString('mobileNumber') ?? '';
    
    try {
      final cloudProfile = await SupabaseService().getProfile(_mobileNumber);
      
      if (cloudProfile != null) {
        _currentUserRole = cloudProfile.userRole;
        _nameController.text = cloudProfile.name;
        _bioController.text = cloudProfile.bio;
        _cityController.text = cloudProfile.city;
        _selectedCity = cloudProfile.city;
        _stateController.text = cloudProfile.state;
        _selectedState = cloudProfile.state;
        _professionController.text = cloudProfile.profession;
        _educationController.text = cloudProfile.education;
        _languagesController.text = cloudProfile.languages.join(', ');
        _base64Image = cloudProfile.profileImageUrl;
        _selectedGender = cloudProfile.gender;
        _age = cloudProfile.age;
        
        // Filter out roles that don't match the gender (prevents corrupted data display)
        _selectedRoles = cloudProfile.possibleRoles
            .where((r) => r.isValidForGender(_selectedGender))
            .map((r) => r.toLabel())
            .toList();
        
        if (mounted) setState(() {});
      } else {
        // Local fallback - only if mobile number matches what's in local prefs
        // Actually, AuthScreen now clears these if number changes, so this is safer.
        _nameController.text = prefs.getString('userName') ?? '';
        _bioController.text = prefs.getString('userBio') ?? '';
        _cityController.text = prefs.getString('userCity') ?? '';
        _selectedCity = _cityController.text;
        _stateController.text = prefs.getString('userState') ?? '';
        _selectedState = _stateController.text;
        _professionController.text = prefs.getString('userProfession') ?? '';
        _educationController.text = prefs.getString('userEducation') ?? '';
        _languagesController.text = (prefs.getStringList('userLanguages') ?? []).join(', ');
        _base64Image = prefs.getString('userImageBase64');
        _selectedGender = prefs.getString('userGender') ?? 'Male';
        _age = prefs.getInt('userAge') ?? 25;
        _selectedRoles = prefs.getStringList('userRoles') ?? [];
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
    setState(() {
      _isLoading = false;
    });
  }

  List<String> _getRolesForGender(String gender) {
    return FamilyRole.values.where((role) {
      if (role == FamilyRole.other) return true;
      final fixedGender = EventRole.getFixedGender(role);
      if (fixedGender == null) return true; // Flexible roles like Friend, Colleague, Neighbor
      if (gender == 'Other') return true; // 'Other' gender can play any role
      return fixedGender == gender;
    }).map((role) => role.toLabel()).toList();
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
    if (_base64Image == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload a profile picture')));
      return;
    }
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your full name')));
      return;
    }
    if (_stateController.text.trim().isEmpty || _stateController.text.contains('Select State')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select your state')));
      return;
    }
    if (_cityController.text.trim().isEmpty || _cityController.text.contains('Select City')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select your city')));
      return;
    }
    if (_professionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your profession')));
      return;
    }
    if (_educationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your education')));
      return;
    }
    if (_languagesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter languages you speak')));
      return;
    }
    if (_selectedRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one role you can play')));
      return;
    }
    if (_bioController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please write a short bio')));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', _nameController.text);
    await prefs.setString('userBio', _bioController.text);
    await prefs.setString('userCity', _cityController.text);
    await prefs.setString('userState', _stateController.text);
    await prefs.setString('userProfession', _professionController.text);
    await prefs.setString('userEducation', _educationController.text);
    final languages = _languagesController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    await prefs.setStringList('userLanguages', languages);
    if (_base64Image != null) await prefs.setString('userImageBase64', _base64Image!);
    await prefs.setString('userGender', _selectedGender);
    await prefs.setInt('userAge', _age);
    await prefs.setStringList('userRoles', _selectedRoles);
    await prefs.setBool('hasProfile', true);

    // Save to Supabase
    final user = BaratiUser(
      id: _mobileNumber,
      name: _nameController.text,
      age: _age,
      gender: _selectedGender,
      userRole: _currentUserRole,
      possibleRoles: _selectedRoles.map((r) => FamilyRoleHelper.fromLabel(r)).toList(),
      bio: _bioController.text,
      profileImageUrl: _base64Image,
      city: _selectedCity,
      state: _selectedState,
      profession: _professionController.text,
      education: _educationController.text,
      languages: languages,
    );
    
    await SupabaseService().upsertProfile(user);

    if (!mounted) return;

    if (widget.isEditMode) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!')));
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const HomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final availableRoles = _getRolesForGender(_selectedGender);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: widget.isEditMode,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (!widget.isEditMode) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please complete your profile to continue')),
          );
        }
      },
      child: Scaffold(
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
                    backgroundImage: _base64Image != null && _base64Image!.startsWith('http')
                      ? NetworkImage(_base64Image!) as ImageProvider
                      : _base64Image != null 
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
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.phone_android, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      _mobileNumber,
                      style: GoogleFonts.montserrat(color: Colors.grey[600], fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.lock_outline, size: 14, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildLabel('Full Name'),
            _buildTextField(controller: _nameController, hint: 'e.g. Rahul Sharma', icon: Icons.person_outline),
            const SizedBox(height: 20),
            _buildLabel('Country / State / City'),
            CSCPickerPlus(
              showStates: true,
              showCities: true,
              flagState: CountryFlag.DISABLE,
              cityLanguage: CityLanguage.native,
              countryStateLanguage: CountryStateLanguage.englishOrNative,
              dropdownDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.grey[50],
                border: Border.all(color: Colors.grey[200]!),
              ),
              disabledDropdownDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.grey[100],
                border: Border.all(color: Colors.grey[200]!),
              ),
              selectedItemStyle: GoogleFonts.montserrat(fontSize: 14, color: Colors.black),
              dropdownHeadingStyle: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold),
              dropdownItemStyle: GoogleFonts.montserrat(fontSize: 14),
              dropdownDialogRadius: 20,
              searchBarRadius: 20,
              defaultCountry: CscCountry.India,
              currentCountry: _selectedCountry,
              currentState: _selectedState,
              currentCity: _selectedCity,
              onCountryChanged: (value) {
                setState(() => _selectedCountry = value);
              },
              onStateChanged: (value) {
                setState(() {
                  _selectedState = value ?? '';
                  _stateController.text = _selectedState;
                });
              },
              onCityChanged: (value) {
                setState(() {
                  _selectedCity = value ?? '';
                  _cityController.text = _selectedCity;
                });
              },
            ),
            const SizedBox(height: 20),
            _buildLabel('Profession'),
            _buildTextField(controller: _professionController, hint: 'e.g. Software Engineer', icon: Icons.work_outline),
            const SizedBox(height: 20),
            _buildLabel('Education'),
            _buildTextField(controller: _educationController, hint: 'e.g. B.Tech in CS', icon: Icons.school_outlined),
            const SizedBox(height: 20),
            _buildLabel('Languages Spoken'),
            _buildTextField(controller: _languagesController, hint: 'e.g. Hindi, English, Punjabi', icon: Icons.translate),
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
    ),
  );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(
        text: TextSpan(
          text: label,
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
          children: [
            TextSpan(
              text: ' *',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
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
            // Clear roles that are no longer valid for the new gender
            _selectedRoles = _selectedRoles.where((label) {
              final role = FamilyRoleHelper.fromLabel(label);
              return role.isValidForGender(gender);
            }).toList();
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
