# SERV – Workforce Management & Attendance System

![Flutter](https://img.shields.io/badge/Frontend-Flutter-blue)
![Node.js](https://img.shields.io/badge/Backend-Node.js-green)
![Firebase](https://img.shields.io/badge/Database-Firebase-orange)
![License](https://img.shields.io/badge/License-Educational-lightgrey)

**SERV** is a full-stack workforce management application that enables organizations to efficiently manage employee attendance, real-time location tracking, leave and request workflows, and administrative operations through a unified digital platform.

The system supports both **manual and biometric attendance workflows** and provides **role-based dashboards** for monitoring, approvals, and operational control.

---

## Core Features

- Secure **Employee** and **Admin** authentication  
- **Attendance Management** with check-in / check-out tracking  
- **Attendance Calendar** showing present, absent, leave, and holidays  
- **Real-time Location Tracking** with historical logs  
- **Employee Request Workflow** (Pending / Approved / Rejected)  
- **Admin Dashboard** for employee lifecycle management  
- **Leave & Request Approval System** with filtering and status control  
- **Shift Management Module** for flexible workforce scheduling  

---

## Technology Stack

| Layer | Technology |
|-------|------------|
| Frontend | Flutter (Mobile & Web) |
| Backend | Node.js + Express.js |
| Database | Firebase Firestore |
| Storage | Firebase Storage |
| Authentication | Firebase Admin SDK / JWT |

---

## Project Architecture


SERV/
│
├── backend/ # Node.js + Express REST APIs
│ ├── controllers/
│ ├── routes/
│ ├── config/
│ ├── middleware/
│ ├── package.json
│ └── app.js
│
├── flutter_application_1/ # Flutter frontend
│ ├── lib/
│ │ ├── screens/
│ │ ├── models/
│ │ ├── services/
│ │ └── main.dart
│ ├── assets/
│ └── pubspec.yaml
│
├── screenshots/ # UI preview images
├── README.md
└── .gitignore


---

## Application Screenshots

Login Screen
Attendance Dashboard
Location Tracking
Admin Approval Panel

---

## Setup & Installation

### Backend

```bash
cd backend
npm install
npm start

Create a .env file with:

Firebase credentials
Server port
Secret keys

Frontend (Flutter)
cd flutter_application_1
flutter pub get
flutter run

Run on web:

flutter run -d chrome
Sample API Endpoints
Method	Endpoint	Description
POST	/api/auth/login	Authenticate user
GET	/api/attendance	Fetch attendance
POST	/api/attendance	Mark check-in/out
GET	/api/track	Get tracking history
POST	/api/track	Save location data
GET	/api/requests	Fetch requests
PUT	/api/requests/:id	Approve/Reject

Author
Pavithra
GitHub: https://github.com/pavithra1323

Purpose
Developed as a production-style workforce management prototype for learning, research, and real-world attendance system implementation practice.

License
This repository is intended for educational and demonstration purposes.
