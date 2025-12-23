import 'package:flutter/material.dart';
import 'package:serv_app/Pagesusers/attendance_model_page.dart';
import 'package:serv_app/Pagesusers/my_attendance_page.dart';
import 'package:serv_app/Pagesusers/my_track_page.dart';
import 'package:serv_app/Pagesusers/my_request_page.dart';
import 'package:serv_app/Pagesusers/my_tasks_page.dart';
import 'package:serv_app/Pagesusers/events_page.dart';
import 'package:serv_app/Pagesusers/my_rewards_page.dart';
import 'package:serv_app/Pagesusers/types_of_request_page.dart';

// Theme colors
const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor = Color(0xFF8C6EAF);
const Color kButtonColor = Color(0xFF655193);
const Color kTextColor = Colors.white;
const Color kIconColor = Color(0xFF3D0066); // New icon color from your image

class MyServPage extends StatelessWidget {
  const MyServPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _ServItemData(
        imagePath: 'assets/images/attendance.png',
        label: "Attendance",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MyAttendancePage(
                data: AttendanceData(
                  totalDays: 13,
                  presentCount: 11,
                  absentCount: 2,
                  leaveCount: 0,
                  lateCheckIn: 0,
                  earlyCheckOut: 2,
                  permissionCount: 0,
                  presentDates: [
                    DateTime(2025, 7, 1),
                    DateTime(2025, 7, 2),
                    DateTime(2025, 7, 3),
                    DateTime(2025, 7, 4),
                    DateTime(2025, 7, 5),
                    DateTime(2025, 7, 6),
                    DateTime(2025, 7, 7),
                    DateTime(2025, 7, 8),
                    DateTime(2025, 7, 10),
                    DateTime(2025, 7, 11),
                  ],
                  absentDates: [DateTime(2025, 7, 9), DateTime(2025, 7, 13)],
                ),
              ),
            ),
          );
        },
      ),
      _ServItemData(
        imagePath: 'assets/images/my-track.png',
        label: "My Track",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyTrackPage()),
          );
        },
      ),
      _ServItemData(
        imagePath: 'assets/images/myrequest.png',
        label: "My Request",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyRequestPage()),
          );
        },
      ),
      _ServItemData(
        imagePath: 'assets/images/type_of_request3.png',
        label: "Type of Request",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TypeOfRequestPage()),
          );
        },
      ),
      _ServItemData(
        imagePath: 'assets/images/task5.png',
        label: "My Task",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyTasksPage()),
          );
        },
      ),
      _ServItemData(
        imagePath: 'assets/images/event_icon.png',
        label: "Events Update",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UserEventUpdatesPage()),
          );
        },
      ),
      _ServItemData(
        imagePath: 'assets/images/rewards1.png',
        label: "Rewards",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UserRewardsPage()),
          );
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('My SERV', style: TextStyle(color: kTextColor)),
        backgroundColor: kAppBarColor,
        iconTheme: const IconThemeData(color: kTextColor),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: GridView.builder(
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 20,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return _ServItem(
                imagePath: item.imagePath,
                label: item.label,
                onTap: item.onTap,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ServItemData {
  final String imagePath;
  final String label;
  final VoidCallback onTap;

  _ServItemData({
    required this.imagePath,
    required this.label,
    required this.onTap,
  });
}

class _ServItem extends StatelessWidget {
  final String imagePath;
  final String label;
  final VoidCallback? onTap;

  const _ServItem({required this.imagePath, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: kAppBarColor.withOpacity(0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 36,
                width: 36,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    kIconColor, // Updated icon color here
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(imagePath, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: kTextColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
