import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

class AddEventScreen extends StatefulWidget {
  const AddEventScreen({super.key});

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  
  static const List<String> _cities = [
    'Delhi', 'Mumbai', 'Bangalore', 'Hyderabad', 'Ahmedabad', 'Chennai', 'Kolkata', 'Surat', 
    'Pune', 'Jaipur', 'Lucknow', 'Kanpur', 'Nagpur', 'Indore', 'Thane', 'Bhopal', 'Visakhapatnam', 
    'Pimpri-Chinchwad', 'Patna', 'Vadodara', 'Ghaziabad', 'Ludhiana', 'Agra', 'Nashik', 'Ranchi', 
    'Faridabad', 'Meerut', 'Rajkot', 'Kalyan-Dombivli', 'Vasai-Virar', 'Varanasi', 'Srinagar', 
    'Aurangabad', 'Dhanbad', 'Amritsar', 'Navi Mumbai', 'Allahabad', 'Howrah', 'Gwalior', 
    'Jabalpur', 'Coimbatore', 'Vijayawada', 'Jodhpur', 'Madurai', 'Raipur', 'Kota', 'Guwahati', 
    'Chandigarh', 'Solapur', 'Hubli-Dharwad', 'Bareilly', 'Moradabad', 'Mysore', 'Gurgaon', 
    'Aligarh', 'Jalandhar', 'Tiruchirappalli', 'Bhubaneswar', 'Salem', 'Mira-Bhayandar', 
    'Warangal', 'Guntur', 'Bhiwandi', 'Saharanpur', 'Gorakhpur', 'Bikaner', 'Amravati', 'Noida', 
    'Jamshedpur', 'Bhilai', 'Cuttack', 'Firozabad', 'Kochi', 'Nellore', 'Bhavnagar', 'Dehradun'
  ];

  EventType _selectedType = EventType.marriage;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 30));
  List<FamilyRole> _selectedRoles = [];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
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
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveEvent() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? prefs.getString('mobileNumber') ?? 'anonymous';
      
      final newEvent = BaratiEvent(
        id: const Uuid().v4(),
        hostId: userId,
        title: _titleController.text,
        description: _descriptionController.text,
        date: _selectedDate,
        location: _locationController.text,
        eventType: _selectedType,
        neededRoles: _selectedRoles,
      );

      final eventsJson = prefs.getString('events') ?? '[]';
      List<dynamic> eventsList = json.decode(eventsJson);
      eventsList.add(newEvent.toJson());
      await prefs.setString('events', json.encode(eventsList));

      // Save to Supabase
      await SupabaseService().createEvent(newEvent);

      if (!mounted) return;
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Event', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
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
              _buildLocationAutocomplete(),
              const SizedBox(height: 24),
              _buildSectionTitle('Date'),
              const SizedBox(height: 8),
              InkWell(
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
                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        style: GoogleFonts.montserrat(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Roles You Need'),
              const SizedBox(height: 12),
              _buildRolesSelector(),
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
                    'Create Event',
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
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
    );
  }

  Widget _buildLocationAutocomplete() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Location'),
        const SizedBox(height: 8),
        Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text == '') {
              return const Iterable<String>.empty();
            }
            return _cities.where((String option) {
              return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
            });
          },
          onSelected: (String selection) {
            _locationController.text = selection;
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            // Sync the internal controller with our _locationController
            controller.addListener(() {
              _locationController.text = controller.text;
            });
            if (_locationController.text.isNotEmpty && controller.text.isEmpty) {
              controller.text = _locationController.text;
            }
            
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: 'Search for a city...',
                hintStyle: GoogleFonts.montserrat(color: Colors.grey, fontSize: 14),
                prefixIcon: const Icon(Icons.location_on_outlined, size: 20, color: Colors.grey),
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
              ),
              validator: (value) => value == null || value.isEmpty ? 'Please enter a location' : null,
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width - 48,
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      return ListTile(
                        title: Text(option, style: GoogleFonts.montserrat()),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
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
          case EventType.anniversary: icon = Icons.celebration; break;
          case EventType.death: icon = Icons.church; break;
          case EventType.other: icon = Icons.more_horiz; break;
        }

        return ChoiceChip(
          avatar: Icon(icon, size: 16, color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey),
          label: Text(type.name.toUpperCase()),
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
          backgroundColor: Colors.grey[100],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          side: BorderSide(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent),
        );
      }).toList(),
    );
  }

  Widget _buildRolesSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: FamilyRole.values.map((role) {
        final isSelected = _selectedRoles.contains(role);
        String label = role.name;
        // Humanize camelCase names
        label = label.replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}').toLowerCase();
        label = label[0].toUpperCase() + label.substring(1);
        
        return FilterChip(
          label: Text(label),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedRoles.add(role);
              } else {
                _selectedRoles.remove(role);
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
          backgroundColor: Colors.grey[100],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          side: BorderSide(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent),
        );
      }).toList(),
    );
  }
}
