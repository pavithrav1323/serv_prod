# SERV – Workforce Management & Attendance System

**SERV** is a full-stack workforce management application designed to help organizations efficiently manage employee attendance, real-time location tracking, leave and request workflows, and administrative operations through a unified digital platform.

The system supports both **manual and biometric attendance workflows** and provides **role-based dashboards** for monitoring, approvals, and operational control.

---

## Core Features

- Secure **Employee** and **Admin** authentication  
- **Attendance Management** with check-in and check-out tracking  
- **My Attendance Calendar** displaying present, absent, leave, and holidays  
- **Real-time Location Tracking** with historical activity logs  
- **Employee Request Management** with Pending / Approved / Rejected status  
- **Admin Dashboard** for employee creation and lifecycle management  
- **Leave & Request Approval Workflow** with filters and status control  
- **Shift Management Module** for flexible workforce scheduling  

---

## Technology Stack

**Frontend:** Flutter (Mobile & Web)  
**Backend:** Node.js with Express.js  
**Database:** Firebase Firestore  
**File Storage:** Firebase Storage (for images and uploads)  
**Authentication:** Firebase Admin SDK / Custom JWT-based authentication  

---

## Project Architecture

SERV/
│
├── backend/ # Node.js + Express REST APIs
│ ├── controllers/ # Business logic layer
│ ├── routes/ # API route definitions
│ ├── config/ # Firebase & environment configuration
│ ├── middleware/ # Authentication and validation
│ ├── package.json
│ └── app.js
│
├── flutter_application_1/ # Flutter frontend (mobile & web)
│ ├── lib/
│ │ ├── screens/ # UI screens
│ │ ├── models/ # Data models
│ │ ├── services/ # API integration layer
│ │ └── main.dart
│ ├── assets/
│ └── pubspec.yaml
│
├── screenshots/ # Application UI preview images
├── README.md # Project documentation
└── .gitignore


---

## Application Screenshots
 Login Screen
 Attendance Page
 Location Tracking
 Admin Approval Panel
 Admin Tracking Page
 Home Page

 

---

## Setup & Installation Guide

### 1. Backend Setup

```bash
cd backend
npm install
npm start
