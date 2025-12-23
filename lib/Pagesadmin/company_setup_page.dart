import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'admin_dashboard_page.dart';
import '../models/company_data.dart';
// ✅ Add this for color constants

const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor = Color(0xFF8C6EAF);
const Color kButtonColor = Color(0xFF655193);
const Color kTextColor = Colors.white;

// Company profile model
class CompanyProfile {
  final String name;
  final String adminName;
  final String? logoUrl;

  CompanyProfile({required this.name, required this.adminName, this.logoUrl});

  String get initials {
    final names = name.trim().split(' ');
    if (names.length == 1) {
      return names[0].substring(0, names[0].length > 1 ? 2 : 1).toUpperCase();
    }
    return names.take(2).map((e) => e[0].toUpperCase()).join();
  }

  bool get hasLogo => logoUrl != null && logoUrl!.isNotEmpty;
}

class CompanySetupPage extends StatefulWidget {
  const CompanySetupPage({super.key});

  @override
  State<CompanySetupPage> createState() => _CompanySetupPageState();
}

class _CompanySetupPageState extends State<CompanySetupPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _adminNameController = TextEditingController();
  final TextEditingController _logoUrlController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // Get the token from CompanyData
        final token = CompanyData.token;
        if (token == null || token.isEmpty) {
          throw Exception('Authentication token not found');
        }

        // Prepare the request body
        final requestBody = {
          'companyName': _companyNameController.text.trim(),
          'adminName': _adminNameController.text.trim(),
          'email': CompanyData.email,
          'phone': '', // Add phone field if needed
          'designation': 'Admin', // Default designation
          'website': _logoUrlController.text.trim().isNotEmpty
              ? _logoUrlController.text.trim()
              : null,
        };

        // Send the request to save the company profile
        final response = await http.post(
          Uri.parse('https://api-zmj7dqloiq-el.a.run.app/api/company/profile'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(requestBody),
        );

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          if (responseData['success'] == true) {
            // Navigate to admin dashboard with the new profile
            if (!mounted) return;
            final profile = CompanyProfile(
              name: _companyNameController.text.trim(),
              adminName: _adminNameController.text.trim(),
              logoUrl: _logoUrlController.text.trim().isNotEmpty
                  ? _logoUrlController.text.trim()
                  : null,
            );

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => AdminDashboard(companyProfile: profile),
              ),
            );
          } else {
            throw Exception(
                responseData['message'] ?? 'Failed to save company profile');
          }
        } else {
          throw Exception(
              'Server responded with status: ${response.statusCode}');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [kAppBarColor, kPrimaryBackgroundBottom], // ✅ changed
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 10,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.business, size: 64, color: kAppBarColor), // ✅
                      const SizedBox(height: 16),
                      Text(
                        "Company Setup",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: kAppBarColor, // ✅
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Configure your attendance system",
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 32),

                      // Company Name
                      _buildField(
                        controller: _companyNameController,
                        label: "Company Name",
                        icon: Icons.business,
                        validatorMsg: "Enter company name",
                      ),
                      const SizedBox(height: 16),

                      // Admin Name
                      _buildField(
                        controller: _adminNameController,
                        label: "Admin Name",
                        icon: Icons.person,
                        validatorMsg: "Enter admin name",
                      ),
                      const SizedBox(height: 16),

                      // Logo URL
                      _buildField(
                        controller: _logoUrlController,
                        label: "Logo URL (Optional)",
                        icon: Icons.image,
                        required: false,
                      ),
                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () async {
                                  await _submit();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kButtonColor, // ✅
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: kTextColor, // ✅
                                )
                              : const Text(
                                  "Setup Dashboard",
                                  style: TextStyle(
                                    color: kTextColor, // ✅
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? validatorMsg,
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      validator: (value) {
        if (required && (value == null || value.trim().isEmpty)) {
          return validatorMsg ?? 'Required';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: kAppBarColor), // ✅
        filled: true,
        fillColor: kPrimaryBackgroundBottom.withOpacity(0.1), // ✅
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kAppBarColor, width: 2), // ✅
        ),
      ),
    );
  }
}
