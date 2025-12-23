

class AttendanceData {
  final int totalDays;
  final int presentCount;
  final int absentCount;
  final int leaveCount;
  final int lateCheckIn;
  final int earlyCheckOut;
  final int permissionCount;
  final List<DateTime> presentDates;
  final List<DateTime> absentDates;

  AttendanceData({
    required this.totalDays,
    required this.presentCount,
    required this.absentCount,
    required this.leaveCount,
    required this.lateCheckIn,
    required this.earlyCheckOut,
    required this.permissionCount,
    required this.presentDates,
    required this.absentDates,
  });

  get leaveDates => null;
}
