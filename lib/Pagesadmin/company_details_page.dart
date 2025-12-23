import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:serv_app/Pagesadmin/admin_dashboard_page.dart';
import 'package:serv_app/Pagesadmin/company_setup_page.dart';
import 'package:serv_app/models/company_data.dart';

// Theme colors
const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor = Color(0xFF8C6EAF);
const Color kButtonColor = Color(0xFF655193);
const Color kTextColor = Colors.white;

class CompanyDetailsFormPage extends StatefulWidget {
  const CompanyDetailsFormPage({super.key});

  @override
  _CompanyDetailsFormPageState createState() => _CompanyDetailsFormPageState();
}

class _CompanyDetailsFormPageState extends State<CompanyDetailsFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _adminNameController = TextEditingController();
  final _adminRoleController = TextEditingController();

  XFile? _logoFile;
  bool _isSubmitting = false;
  final ImagePicker _picker = ImagePicker();

  // Helper method to get MIME type from file extension
  String _getMimeType(String path) {
    final extension = path.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      default:
        return 'application/octet-stream';
    }
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _adminNameController.dispose();
    _adminRoleController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _logoFile = picked);
  }

  String? _validateRequired(String? v) =>
      v == null || v.trim().isEmpty ? 'Required' : null;
  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final pattern =
        r'^[A-Za-z0-9]+([._-]?[A-Za-z0-9]+)*@[A-Za-z0-9-]+(\.[A-Za-z]{2,})+$';
    return RegExp(pattern).hasMatch(v.trim()) ? null : 'Enter a valid email';
  }

  String? _validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    return v.trim().length == 10 ? null : 'Must be 10 digits';
  }

  String? _validateUrl(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final uri = Uri.tryParse(v.trim());
    return (uri != null &&
            uri.hasScheme &&
            (uri.scheme == 'http' || uri.scheme == 'https'))
        ? null
        : 'Enter a valid URL';
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final token = CompanyData.token;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token missing')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Save fields into shared model
      CompanyData.companyName = _companyNameController.text.trim();
      CompanyData.email = _emailController.text.trim();
      CompanyData.phone = _phoneController.text.trim();
      CompanyData.website = _websiteController.text.trim();
      CompanyData.adminName = _adminNameController.text.trim();
      CompanyData.adminRole = _adminRoleController.text.trim();

      // Prepare request body
      final Map<String, dynamic> requestBody = {
        'companyName': CompanyData.companyName,
        'email': CompanyData.email,
        'phone': CompanyData.phone,
        'website': CompanyData.website,
        'adminName': CompanyData.adminName,
        'designation': CompanyData.adminRole,
      };

      // Add base64 encoded image if available
      if (_logoFile != null) {
        final Uint8List bytes = await _logoFile!.readAsBytes();
        final String base64Image = base64Encode(bytes);
        final String mimeType = _getMimeType(_logoFile!.path);

        requestBody['logoBase64'] = base64Image;
        requestBody['logoMimeType'] = mimeType;
      }

      // Send the request
      final response = await http.post(
        Uri.parse('https://api-zmj7dqloiq-el.a.run.app/api/company/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      setState(() => _isSubmitting = false);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('Response data: $responseData'); // Debug log

        // Check for success message in the response
        final bool isSuccess = responseData['message']
                ?.toString()
                .toLowerCase()
                .contains('success') ??
            false;

        if (isSuccess) {
          print(
              'Company profile saved successfully, navigating to AdminDashboard...');
          if (mounted) {
            // Add a small delay to ensure the UI updates before navigation
            await Future.delayed(const Duration(milliseconds: 300));
            if (!mounted) return;

            // Navigate to AdminDashboard with the company profile data
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => AdminDashboard(
                  companyProfile: CompanyProfile(
                    name: CompanyData.companyName,
                    adminName: CompanyData.adminName,
                    logoUrl: _logoFile?.path,
                  ),
                ),
              ),
              (route) => false, // This removes all previous routes
            );
          } else {
            print('Widget not mounted, cannot navigate');
          }
        } else {
          print('Server returned success: false'); // Debug log
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text(responseData['message'] ?? 'Submission failed')),
            );
          }
        }
      } else {
        final errorData = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorData['message'] ??
                    'Submission failed: ${response.statusCode}',
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width > 600;
    final double spacing = isWide ? 24.0 : 16.0;

    return Scaffold(
      backgroundColor: kPrimaryBackgroundTop,
      appBar: AppBar(
        backgroundColor: kAppBarColor,
        title: const Text(
          'Company Details',
          style: TextStyle(color: kTextColor),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(spacing),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_logoFile != null) ...[
                    Center(
                      child: CircleAvatar(
                        radius: 48,
                        backgroundImage: kIsWeb
                            ? NetworkImage(_logoFile!.path)
                            : FileImage(File(_logoFile!.path)) as ImageProvider,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kButtonColor,
                        foregroundColor: kTextColor,
                      ),
                      onPressed: _pickLogo,
                      child: const Text('Upload Logo'),
                    ),
                  ),
                  SizedBox(height: spacing),
                  TextFormField(
                    controller: _companyNameController,
                    decoration: const InputDecoration(
                      labelText: 'Company Name',
                    ),
                    validator: _validateRequired,
                  ),
                  SizedBox(height: spacing),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Official Email Address',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: _validateEmail,
                  ),
                  SizedBox(height: spacing),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                    ),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: _validatePhone,
                  ),
                  SizedBox(height: spacing),
                  TextFormField(
                    controller: _websiteController,
                    decoration: const InputDecoration(
                      labelText: 'Official Website (optional)',
                    ),
                    keyboardType: TextInputType.url,
                    validator: _validateUrl,
                  ),
                  SizedBox(height: spacing),
                  TextFormField(
                    controller: _adminNameController,
                    decoration: const InputDecoration(
                      labelText: 'Admin Full Name',
                    ),
                    validator: _validateRequired,
                  ),
                  SizedBox(height: spacing),
                  TextFormField(
                    controller: _adminRoleController,
                    decoration: const InputDecoration(
                      labelText: 'Admin Designation',
                    ),
                    validator: _validateRequired,
                  ),
                  SizedBox(height: spacing * 1.5),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kButtonColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Submit',
                              style: TextStyle(color: kTextColor),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
