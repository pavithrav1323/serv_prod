import 'package:flutter/material.dart';
import 'package:serv_app/Pagesadmin/workdays_shift_page.dart';
import 'package:serv_app/Pagesadmin/leave_page.dart';
import 'package:serv_app/Pagesadmin/profile_page.dart';
import 'package:serv_app/Pagesadmin/reason_master_page.dart';
import 'package:serv_app/Pagesadmin/office_location_page.dart';

// Theme colors
const Color kPrimaryBackgroundTop    = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor             = Color(0xFF8C6EAF);
const Color kButtonColor             = Color(0xFF655193);
const Color kTextColor               = Colors.white;

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  void _handleItemClick(BuildContext context, String title) {
    if (title == 'Workdays & Shift Permission') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkdaysShiftPage()));
    } else if (title == 'Leave Holiday') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LeavePage()));
    } else if (title == 'Profile') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CompanyProfilePage()));
    } else if (title == 'Reason Master') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ReasonMasterPage()));
    } else if (title == 'Office Location') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const OfficeLocationPage()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$title clicked')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
          ),
        ),
        child: Center(
          child: Container(
            width: 380,
            margin: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kAppBarColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: kTextColor,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Divider(color: kTextColor.withOpacity(0.3), thickness: 1),
                  const SizedBox(height: 16),

                  sectionTitle("Work Schedule"),
                  _menuItem(context, "Workdays & Shift Permission", Icons.calendar_today),
                  _menuItem(context, "Leave Holiday", Icons.beach_access),

                  const SizedBox(height: 20),
                  sectionTitle("Corporate"),
                  _menuItem(context, "Profile", Icons.business_center),
                  _menuItem(context, "Office Location", Icons.location_on),

                  const SizedBox(height: 20),
                  sectionTitle("Admin"),
                  _menuItem(context, "Reason Master", Icons.edit_note),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Section title with **black** color
  Widget sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
          color: Colors.black, // Changed from kButtonColor to black
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      );

  /// Reusable menu item card
  Widget _menuItem(BuildContext context, String title, IconData icon) => InkWell(
        onTap: () => _handleItemClick(context, title),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: kButtonColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: kTextColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: kTextColor,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: kTextColor),
            ],
          ),
        ),
      );
}
