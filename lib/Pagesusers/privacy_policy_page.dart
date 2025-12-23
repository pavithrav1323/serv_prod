import 'package:flutter/material.dart';

// Theme Colors
const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor = Color(0xFF8C6EAF);

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Privacy Policy',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: kAppBarColor,
        centerTitle: false,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Text(
              '''
This Privacy Policy describes how your personal information is collected, used, and shared when you use our Attendance Management App.

1. Data Collection
We may collect your name, employee ID, location, face data (for recognition), and usage data.

2. Use of Data
We use your information to provide and improve the attendance tracking features, ensure secure authentication, and generate attendance reports.

3. Data Sharing
We do not sell or share your data with third-party organizations except as required by law.

4. Security
We take appropriate measures to protect your data but cannot guarantee complete security.

5. User Rights
You have the right to access or delete your data. Contact your administrator for requests.

6. Changes
We may update this policy. Check this page regularly for any changes.

If you have any questions about this policy, contact the admin.

Thank you for using our app!
              ''',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}
