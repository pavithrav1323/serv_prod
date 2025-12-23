import 'package:flutter/material.dart';
import 'package:serv_app/Pagesusers/apply_leave_form_page.dart';
import 'request_leave_page.dart';
import 'permission_time_page.dart';
import 'over_time_page.dart';
import 'half_day_time_page.dart';

// Theme colors
const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor = Color(0xFF8C6EAF);
const Color kButtonColor = Color(0xFF655193);
const Color kTextColor = Colors.white;
const Color kIconColor = Color(0xFF3D0066);

class TypeOfRequestPage extends StatelessWidget {
  const TypeOfRequestPage({super.key});

  final List<Map<String, dynamic>> requestTypes = const [
    {'title': 'Leave Type', 'icon': Icons.calendar_today},
    {'title': 'Permission Time', 'icon': Icons.access_time},
    {'title': 'Over Time', 'icon': Icons.timer},
    {'title': 'Half Day Time', 'icon': Icons.timelapse},
    {'title': 'Comp Off', 'icon': Icons.sync_alt},
  ];

  void _handleNavigation(BuildContext context, String title) {
    if (title == 'Leave Type') {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const RequestLeavePage(),
      );
    } else if (title == 'Permission Time') {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const PermissionTimePage(isPopup: false),
      );
    } else if (title == 'Over Time') {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const OverTimePage(isPopup: false),
      );
    } else if (title == 'Half Day Time') {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const HalfDayTimePage(
          isPopup: false,
          totalHalfDays: 8,
          takenHalfDays: 4,
          status: "Available",
        ),
      );
    } else if (title == 'Comp Off') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ApplyHalfDayForm()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Type Of Requests", style: TextStyle(fontSize: 18)),
        backgroundColor: kAppBarColor,
        centerTitle: false,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
          ),
        ),
        alignment: Alignment.topCenter, // ❗️Align tiles to top
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            itemCount: requestTypes.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 20,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1, // Matches myserv_page.dart
            ),
            itemBuilder: (context, index) {
              final item = requestTypes[index];
              return GestureDetector(
                onTap: () => _handleNavigation(context, item['title']),
                child: Card(
                  color: kAppBarColor.withOpacity(0.9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 36,
                          width: 36,
                          child: ColorFiltered(
                            colorFilter: const ColorFilter.mode(
                              kIconColor,
                              BlendMode.srcIn,
                            ),
                            child: Icon(item['icon'], size: 28),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['title'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: kTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
