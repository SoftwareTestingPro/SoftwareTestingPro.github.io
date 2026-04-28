import 'package:csc_picker_plus/csc_picker_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/event_logic.dart';

class AddEventScreen extends StatefulWidget {
  final BaratiEvent? eventToEdit;
  final VoidCallback? onSaveComplete;
  const AddEventScreen({super.key, this.eventToEdit, this.onSaveComplete});

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  final _descriptionController = TextEditingController();
  
  String _selectedCountry = 'India';
  String _selectedState = '';
  String _selectedCity = '';

  late EventType _selectedType;
  late DateTime _selectedDate;
  late List<EventRole> _selectedRoles;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.eventToEdit?.title);
    _descriptionController.text = widget.eventToEdit?.description ?? '';
    
    // Parse location if editing
    if (widget.eventToEdit?.location != null) {
      final parts = widget.eventToEdit!.location.split(', ');
      if (parts.length >= 2) {
        _selectedCity = parts[0];
        _selectedState = parts[1];
      } else {
        _selectedCity = widget.eventToEdit!.location;
      }
    }
    
    _selectedType = widget.eventToEdit?.eventType ?? EventType.marriage;
    _selectedDate = widget.eventToEdit?.date ?? DateTime.now().add(const Duration(days: 30));
    _selectedRoles = widget.eventToEdit != null ? List.from(widget.eventToEdit!.neededRoles) : [];
    _imageUrl = widget.eventToEdit?.imageUrl;
    _selectedCity = widget.eventToEdit?.city ?? _selectedCity;
    _selectedState = widget.eventToEdit?.state ?? _selectedState;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().isBefore(_selectedDate) ? DateTime.now() : _selectedDate,
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  Future<void> _saveEvent() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedCity.isEmpty || _selectedCity.contains('Select City')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a valid city')),
        );
        return;
      }
      if (_selectedRoles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one role')),
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? prefs.getString('mobileNumber') ?? 'anonymous';
      
      final cleanCity = (_selectedCity == 'City' || _selectedCity.contains('Select City')) ? '' : _selectedCity;
      final cleanState = (_selectedState == 'State' || _selectedState.contains('Select State')) ? '' : _selectedState;
      
      final event = BaratiEvent(
        id: widget.eventToEdit?.id ?? const Uuid().v4(),
        hostId: widget.eventToEdit?.hostId ?? userId,
        title: _titleController.text,
        description: _descriptionController.text,
        date: _selectedDate,
        location: cleanCity.isNotEmpty ? '$cleanCity, $cleanState' : cleanState,
        eventType: _selectedType,
        neededRoles: _selectedRoles,
        approvedMemberIds: widget.eventToEdit?.approvedMemberIds ?? [],
        imageUrl: _imageUrl ?? EventLogic.getDefaultImageUrl(_selectedType),
        city: cleanCity,
        state: cleanState,
      );

      // Save to Supabase
      if (widget.eventToEdit == null) {
        await SupabaseService().createEvent(event);
      } else {
        await SupabaseService().updateEvent(event);
      }

      // Sync local (optional/legacy)
      final eventsJson = prefs.getString('events') ?? '[]';
      List<dynamic> eventsList = json.decode(eventsJson);
      if (widget.eventToEdit == null) {
        eventsList.add(event.toJson());
      } else {
        final index = eventsList.indexWhere((e) => e['id'] == event.id);
        if (index != -1) {
          eventsList[index] = event.toJson();
        } else {
          eventsList.add(event.toJson());
        }
      }
      await prefs.setString('events', json.encode(eventsList));

      if (widget.onSaveComplete != null) {
        widget.onSaveComplete!();
      } else {
        if (!mounted) return;
        Navigator.pop(context, true);
      }
    }
  }

  Widget _buildGlowShape(double size, Color color, {bool isCircle = true}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle ? null : BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 40,
            spreadRadius: 20,
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isCircle ? null : BorderRadius.circular(size * 0.3),
        ),
      ),
    );
  }

  Widget _buildPageBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFF3E5F5).withOpacity(0.5), // Soft Lavender
            const Color(0xFFE1F5FE).withOpacity(0.5), // Soft Sky
            Colors.white,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 40,
            right: -20,
            child: _buildGlowShape(120, Colors.purple.withOpacity(0.2)),
          ),
          Positioned(
            top: 400,
            left: -40,
            child: _buildGlowShape(180, Colors.blue.withOpacity(0.15)),
          ),
          Positioned(
            bottom: 100,
            right: 40,
            child: _buildGlowShape(150, Colors.pink.withOpacity(0.1)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.eventToEdit == null ? 'Create Event' : 'Update Event', 
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Stack(
        children: [
          _buildPageBackground(),
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              _buildSectionTitle('What kind of event?'),
              const SizedBox(height: 12),
              _buildEventTypeSelector(),
              const SizedBox(height: 24),
              _buildTextField('Event Title', _titleController, 'e.g. Rahul & Priya\'s Wedding'),
              const SizedBox(height: 16),
              _buildTextField('Description', _descriptionController, 'Tell people about the event...', maxLines: 3),
              const SizedBox(height: 16),
              _buildSectionTitle('Location'),
              const SizedBox(height: 8),
              CSCPickerPlus(
                showStates: true,
                showCities: true,
                flagState: CountryFlag.DISABLE,
                cityLanguage: CityLanguage.native,
                countryStateLanguage: CountryStateLanguage.englishOrNative,
                dropdownDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[300]!),
                ),
                disabledDropdownDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[50],
                  border: Border.all(color: Colors.grey[300]!),
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
                  setState(() => _selectedState = value ?? '');
                },
                onCityChanged: (value) {
                  setState(() => _selectedCity = value ?? '');
                },
              ),
              _buildSectionTitle('Date & Time'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                            const SizedBox(width: 12),
                            Text(
                              EventLogic.formatDate(_selectedDate),
                              style: GoogleFonts.montserrat(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, size: 20, color: Colors.grey),
                            const SizedBox(width: 12),
                            Text(
                              EventLogic.formatTime(_selectedDate),
                              style: GoogleFonts.montserrat(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Roles You Need'),
              const SizedBox(height: 12),
              _buildRolesSelector(),
              if (_selectedRoles.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildSectionTitle('Role Details'),
                const SizedBox(height: 12),
                _buildRoleDetailsList(),
              ],
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _saveEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(
                    widget.eventToEdit == null ? 'Create Event' : 'Update Event',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                  ),
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    ],
  ),
);
}

  List<String> _getNeededForOptions(EventType type) {
    switch (type) {
      case EventType.marriage:
      case EventType.haldi:
      case EventType.mehndi:
      case EventType.sangeet:
      case EventType.reception:
      case EventType.engagement:
        return ['Bride', 'Groom', 'Other'];
      case EventType.birthday:
        return ['Birthday Person', 'Other'];
      case EventType.babyShower:
        return ['Mother to be', 'Other'];
      case EventType.houseWarming:
      case EventType.houseParty:
      case EventType.anniversary:
        return ['Host', 'Other'];
      case EventType.death:
        return ['Family', 'Other'];
      default:
        return ['Host', 'Other'];
    }
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
    );
  }


  Widget _buildTextField(String label, TextEditingController controller, String hint, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.montserrat(color: Colors.grey, fontSize: 14),
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
          ),
          validator: (value) => value == null || value.isEmpty ? 'Please enter $label' : null,
        ),
      ],
    );
  }

  Widget _buildEventTypeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: EventType.values.map((type) {
        final isSelected = _selectedType == type;
        IconData icon;
        switch (type) {
          case EventType.marriage: icon = Icons.favorite; break;
          case EventType.haldi: icon = Icons.wb_sunny; break;
          case EventType.mehndi: icon = Icons.brush; break;
          case EventType.sangeet: icon = Icons.music_note; break;
          case EventType.reception: icon = Icons.celebration; break;
          case EventType.engagement: icon = Icons.ring_volume; break;
          case EventType.birthday: icon = Icons.cake; break;
          case EventType.babyShower: icon = Icons.child_care; break;
          case EventType.houseWarming: icon = Icons.home; break;
          case EventType.anniversary: icon = Icons.star; break;
          case EventType.death: icon = Icons.church; break;
          case EventType.houseParty: icon = Icons.liquor; break;
          case EventType.other: icon = Icons.more_horiz; break;
        }

        return ChoiceChip(
          avatar: Icon(icon, size: 16, color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey),
          label: Text(type.name.replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}').toUpperCase()),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) setState(() => _selectedType = type);
          },
          selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          labelStyle: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[600],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          side: BorderSide(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[300]!),
        );
      }).toList(),
    );
  }

  Widget _buildRolesSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: FamilyRole.values.map((role) {
        final isSelected = _selectedRoles.any((r) => r.role == role);
        String label = role.toLabel();
        
        return FilterChip(
          label: Text(label),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                final fixedGender = EventRole.getFixedGender(role);
                _selectedRoles.add(EventRole(
                  role: role, 
                  description: '', 
                  gender: fixedGender ?? 'Any',
                  forWhom: _getNeededForOptions(_selectedType)[0], // Default to first relevant option
                ));
              } else {
                _selectedRoles.removeWhere((r) => r.role == role);
              }
            });
          },
          selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          checkmarkColor: Theme.of(context).colorScheme.primary,
          labelStyle: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[600],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          side: BorderSide(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[300]!),
        );
      }).toList(),
    );
  }

  Widget _buildRoleDetailsList() {
    return Column(
      children: _selectedRoles.map((roleInfo) {
        String label = roleInfo.role.toLabel();

        final fixedGender = EventRole.getFixedGender(roleInfo.role);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _selectedRoles.removeWhere((r) => r.role == roleInfo.role);
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: roleInfo.description,
                decoration: InputDecoration(
                  hintText: 'Describe who you\'re looking for...',
                  hintStyle: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                maxLines: 2,
                onChanged: (val) {
                  final index = _selectedRoles.indexWhere((r) => r.role == roleInfo.role);
                  _selectedRoles[index] = EventRole(
                    role: roleInfo.role,
                    description: val,
                    gender: roleInfo.gender,
                    forWhom: roleInfo.forWhom,
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Needed for:', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  ..._getNeededForOptions(_selectedType).map((side) {
                    final isSel = roleInfo.forWhom == side;
                    return Padding(
                      padding: const EdgeInsets.only(right: 4.0),
                      child: ChoiceChip(
                        label: Text(side),
                        selected: isSel,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              final index = _selectedRoles.indexWhere((r) => r.role == roleInfo.role);
                              _selectedRoles[index] = EventRole(
                                role: roleInfo.role,
                                description: roleInfo.description,
                                gender: roleInfo.gender,
                                forWhom: side,
                              );
                            });
                          }
                        },
                        selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        labelStyle: GoogleFonts.montserrat(
                          fontSize: 10,
                          color: isSel ? Theme.of(context).colorScheme.primary : Colors.grey,
                        ),
                        backgroundColor: Colors.white,
                        side: BorderSide(color: isSel ? Theme.of(context).colorScheme.primary : Colors.grey[300]!),
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  }).toList(),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('Gender:', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  if (fixedGender != null)
                    Chip(
                      label: Text(fixedGender),
                      backgroundColor: Colors.blue.withOpacity(0.1),
                      labelStyle: GoogleFonts.montserrat(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide.none,
                    )
                  else
                    ...['Male', 'Female', 'Any'].map((g) {
                      final isSel = roleInfo.gender == g;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(g),
                          selected: isSel,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                final index = _selectedRoles.indexWhere((r) => r.role == roleInfo.role);
                                _selectedRoles[index] = EventRole(
                                  role: roleInfo.role,
                                  description: roleInfo.description,
                                  gender: g,
                                  forWhom: roleInfo.forWhom,
                                );
                              });
                            }
                          },
                          selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          labelStyle: GoogleFonts.montserrat(
                            fontSize: 10,
                            color: isSel ? Theme.of(context).colorScheme.primary : Colors.grey,
                          ),
                          backgroundColor: Colors.white,
                          side: BorderSide(color: isSel ? Theme.of(context).colorScheme.primary : Colors.grey[300]!),
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    }).toList(),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
