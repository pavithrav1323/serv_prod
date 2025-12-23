import 'package:flutter/material.dart';

// Color constants
const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor = Color(0xFF8C6EAF);
const Color kButtonColor = Color(0xFF655193);
const Color kTextColor = Colors.white;

class MultiLanguagePage extends StatefulWidget {
  const MultiLanguagePage({super.key});

  @override
  State<MultiLanguagePage> createState() => _MultiLanguagePageState();
}

class _MultiLanguagePageState extends State<MultiLanguagePage> {
  String _selectedLanguage = 'English';

  final List<String> _languages = [
    'English',

  ];

  void _onLanguageSelected(String language) {
    setState(() {
      _selectedLanguage = language;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$language selected')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Language'),
        backgroundColor: kAppBarColor,
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
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _languages.length,
          itemBuilder: (context, index) {
            String language = _languages[index];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: RadioListTile<String>(
                  value: language,
                  groupValue: _selectedLanguage,
                  onChanged: (value) => _onLanguageSelected(value!),
                  title: Text(
                    language,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
