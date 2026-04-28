import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_screen.dart';
import 'home_screen.dart';
import '../services/supabase_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isOtpSent = false;
  final String _staticOtp = "1234";
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pre-cache the background image for smoother transition
    precacheImage(const AssetImage('assets/images/party_bg.png'), context);
  }

  Future<void> _sendOtp() async {
    if (_phoneController.text.length == 4) {
      setState(() => _isOtpSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP sent: 1234 (Static)')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a 4-digit Mobile Number')),
      );
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text == _staticOtp) {
      final prefs = await SharedPreferences.getInstance();
      final String? oldMobileNumber = prefs.getString('mobileNumber');
      final String currentMobileNumber = _phoneController.text;

      // If a different user is logging in, clear previous local profile data
      if (oldMobileNumber != null && oldMobileNumber != currentMobileNumber) {
        await prefs.remove('hasProfile');
        await prefs.remove('userName');
        await prefs.remove('userBio');
        await prefs.remove('userCity');
        await prefs.remove('userState');
        await prefs.remove('userProfession');
        await prefs.remove('userEducation');
        await prefs.remove('userLanguages');
        await prefs.remove('userImageBase64');
        await prefs.remove('userGender');
        await prefs.remove('userAge');
        await prefs.remove('userRoles');
      }

      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('mobileNumber', currentMobileNumber);
      
      // Check cloud profile
      final cloudProfile = await SupabaseService().getProfile(currentMobileNumber);
      
      final bool hasProfile = (cloudProfile != null);
      await prefs.setBool('hasProfile', hasProfile);

      if (!mounted) return;
      
      if (hasProfile) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid OTP. Use 1234')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: Stack(
        children: [
          _buildBackground(),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Welcome to Barati',
                      style: theme.textTheme.displayLarge?.copyWith(fontSize: 28),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isOtpSent ? 'Enter the OTP sent to your phone' : 'Sign in to your chosen family',
                      style: GoogleFonts.montserrat(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    if (!_isOtpSent) ...[
                      _buildTextField(
                        controller: _phoneController,
                        hint: '4-Digit Mobile Number',
                        icon: Icons.phone_android,
                        keyboardType: TextInputType.phone,
                        maxLength: 4,
                      ),
                      const SizedBox(height: 24),
                      _buildButton(
                        text: 'Send OTP',
                        onPressed: _sendOtp,
                      ),
                    ] else ...[
                      _buildTextField(
                        controller: _otpController,
                        hint: 'Enter 4-digit OTP',
                        icon: Icons.lock_outline,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                      ),
                      const SizedBox(height: 24),
                      _buildButton(
                        text: 'Verify & Login',
                        onPressed: _verifyOtp,
                      ),
                      TextButton(
                        onPressed: () => setState(() => _isOtpSent = false),
                        child: const Text('Change Number'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/app_background.png'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xFF8B0000)),
        hintText: hint,
        hintStyle: GoogleFonts.montserrat(color: Colors.grey),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        counterText: "",
      ),
    );
  }

  Widget _buildButton({required String text, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8B0000),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
        ),
        child: Text(
          text,
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
