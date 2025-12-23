// lib/models/employee.dart
class Employee {
  final String id;
  final String empid;
  final String name;
  final String dept;
  final String location;
  final String shiftGroup;

  Employee({
    required this.id,
    required this.empid,
    required this.name,
    required this.dept,
    required this.location,
    required this.shiftGroup,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'] as String,
      empid: json['empid'] as String,
      name: json['name'] as String,
      dept: json['dept'] as String? ?? '',
      location: json['location'] as String? ?? '',
      shiftGroup: json['shiftGroup'] as String? ?? '',
    );
  }
}
