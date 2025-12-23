import 'package:flutter/material.dart';

// Theme Colors
const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor = Color(0xFF8C6EAF);

class TermsAndConditionsPage extends StatelessWidget {
  const TermsAndConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Terms & Conditions',
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
By using this Attendance Management App, you agree to the following Terms and Conditions:

1. Usage Agreement
You must use the app only for official attendance and tracking purposes.

2. Account Responsibility
You are responsible for maintaining the confidentiality of your login credentials.

3. Data Accuracy
You must ensure the accuracy of the information you provide during check-in or check-out.

4. Prohibited Activities
Any misuse of the app, including false attendance marking or tampering with location data, is strictly prohibited.

5. Termination
We reserve the right to suspend access to users who violate these terms.

6. Modifications
These terms may be updated from time to time. Continued use of the app implies acceptance of any changes.

7. Limitation of Liability
We are not liable for any indirect or incidental damages caused due to usage of this app.

Please review these terms carefully. If you do not agree, please refrain from using the app.

Thank you for your cooperation.
              ''',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}
