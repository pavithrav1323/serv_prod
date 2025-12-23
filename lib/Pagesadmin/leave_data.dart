// // leave_data.dart
// final List<Map<String, dynamic>> allLeaveRequests = [
//   {
//     'type': 'Leave Type',
//     'id': 'EMP003',
//     'name': 'Mohit',
//     'days': 3,
//     'from': '21-07-2025',
//     'to': '23-07-2025',
//     'reason': 'Travel',
//     'status': 'pending'
//   },
//     {
//     'type': 'Leave Type',
//     'id': 'EMP004',
//     'name': 'ANU',
//     'days': 2,
//     'from': '22-07-2025',
//     'to': '24-07-2025',
//     'reason': 'Fever',
//     'status': 'pending'
//   },

//   {
//     'type': 'Permission',
//     'id': 'EMP003',
//     'name': 'Deepi',
//     'shift': 2,
//     'time': '2:00',
//     'date': '22-07-2025',
//     'reason': 'Fever',
//     'status': 'pending'
//   },
//     {
//     'type': 'Permission',
//     'id': 'EMP001',
//     'name': 'Priya',
//     'shift': 1,
//     'time': '3:00',
//     'date': '23-07-2025',
//     'reason': 'Travel',
//     'status': 'pending'
//   },
//   {
//     'type': 'Over Time',
//     'id': 'EMP004',
//     'name': 'Madhu',
//     'shift': 1,
//     'time': '2:00',
//     'date': '25-07-2025',
//     'status': 'pending'
//   },
//     {
//     'type': 'Over Time',
//     'id': 'EMP005',
//     'name': 'Malar',
//     'shift': 3,
//     'time': '1:00',
//     'date': '21-07-2025',
//     'status': 'pending'
//   },
//   {
//     'type': 'Half Day Leave',
//     'id': 'EMP004',
//     'name': 'Madhu',
//     'leaveDate': '22-07-2025',
//     'section': 'Morning',
//     'reason': 'Travel',
//     'status': 'pending'
//   },
//     {
//     'type': 'Half Day Leave',
//     'id': 'EMP008',
//     'name': 'keerthi',
//     'leaveDate': '29-07-2025',
//     'section': 'Evening',
//     'reason': 'personal work',
//     'status': 'pending'
//   },
//   {
//     'type': 'Comp Off',
//     'id': 'EMP004',
//     'name': 'Madhu',
//     'shift': 1,
//     'fromDate': '21-07-2025',
//     'replaceDate': '25-07-2025',
//     'reason': 'Fever',
//     'status': 'pending'
//   },
//     {
//     'type': 'Comp Off',
//     'id': 'EMP006',
//     'name': 'Moni',
//     'shift': 3,
//     'fromDate': '24-07-2025',
//     'replaceDate': '27-07-2025',
//     'reason': 'Travel',
//     'status': 'pending'
//   },
// ];



final List<Map<String, dynamic>> allLeaveRequests = [
  {
    'type': 'Late check in',
    'id': 'EMP007',
    'name': 'Sundar',
    'department': 'IT',
    'requestType': 'Late check in',
    'reason': 'Other Location',
    'shift': 1,
    'shiftGroup': 'A',
    'requestTime': '10:30 AM',
    'requestDate': '28-07-2025',
    'status': 'pending',
    'location': {
      "lat": 13.0827,
      "lng": 80.2707
    }
  },
  {
    'type': 'Late check in',
    'id': 'EMP008',
    'name': 'Suji',
    'department': 'HR',
    'requestType': 'Late check in',
    'reason': 'Other Location',
    'shift': 2,
    'shiftGroup': 'B',
    'requestTime': '11:30 AM',
    'requestDate': '22-07-2025',
    'status': 'pending'
  },
  {
    'type': 'Early check out',
    'id': 'EMP009',
    'name': 'Lakshmi',
    'department': 'HR',
    'requestType': 'Early check out',
    'shift': 2,
    'shiftGroup': 'B',
    'requestTime': '07:30 PM',
    'requestDate': '28-07-2025',
    'status': 'pending'
  },
  {
    'type': 'Early check out',
    'id': 'EMP003',
    'name': 'Loya',
    'department': 'HR',
    'requestType': 'Early check out',
    'shift': 1,
    'shiftGroup': 'A',
    'requestTime': '08:30 PM',
    'requestDate': '2-207-2025',
    'status': 'pending'
  },
  {
    'type': 'Leave Type',
    'id': 'EMP003',
    'name': 'Mohit',
    'days': 3,
    'from': '21-07-2025',
    'to': '23-07-2025',
    'reason': 'Travel',
    'status': 'pending'
  },
  {
    'type': 'Leave Type',
    'id': 'EMP004',
    'name': 'ANU',
    'days': 2,
    'from': '22-07-2025',
    'to': '24-07-2025',
    'reason': 'Fever',
    'status': 'pending'
  },
  {
    'type': 'Permission',
    'id': 'EMP003',
    'name': 'Deepi',
    'shift': 2,
    'time': '2:00',
    'date': '22-07-2025',
    'reason': 'Fever',
    'status': 'pending'
  },
  {
    'type': 'Permission',
    'id': 'EMP001',
    'name': 'Priya',
    'shift': 1,
    'time': '3:00',
    'date': '23-07-2025',
    'reason': 'Travel',
    'status': 'pending'
  },
  {
    'type': 'Over Time',
    'id': 'EMP004',
    'name': 'Madhu',
    'shift': 1,
    'time': '2:00',
    'date': '25-07-2025',
    'status': 'pending'
  },
  {
    'type': 'Over Time',
    'id': 'EMP005',
    'name': 'Malar',
    'shift': 3,
    'time': '1:00',
    'date': '21-07-2025',
    'status': 'pending'
  },
  {
    'type': 'Half Day Leave',
    'id': 'EMP004',
    'name': 'Madhu',
    'leaveDate': '22-07-2025',
    'section': 'Morning',
    'reason': 'Travel',
    'status': 'pending'
  },
  {
    'type': 'Half Day Leave',
    'id': 'EMP008',
    'name': 'keerthi',
    'leaveDate': '29-07-2025',
    'section': 'Evening',
    'reason': 'personal work',
    'status': 'pending'
  },
  {
    'type': 'Comp Off',
    'id': 'EMP004',
    'name': 'Madhu',
    'shift': 1,
    'fromDate': '21-07-2025',
    'replaceDate': '25-07-2025',
    'reason': 'Fever',
    'status': 'pending'
  },
  {
    'type': 'Comp Off',
    'id': 'EMP006',
    'name': 'Moni',
    'shift': 3,
    'fromDate': '24-07-2025',
    'replaceDate': '27-07-2025',
    'reason': 'Travel',
    'status': 'pending'
  },
];