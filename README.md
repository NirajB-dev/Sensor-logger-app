# EMF Sensor Data Logger & Analytics Dashboard

> **A comprehensive mobile sensor data collection and visualization system for EMF (Electromagnetic Field) monitoring with heart rate correlation analysis.**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev/)
[![Python](https://img.shields.io/badge/Python-3.8+-green.svg)](https://www.python.org/)
[![Firebase](https://img.shields.io/badge/Firebase-Realtime-orange.svg)](https://firebase.google.com/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Data Flow](#data-flow)
- [Firebase Setup](#firebase-setup)
- [Web Dashboard](#web-dashboard)
- [Contributing](#contributing)
- [License](#license)

## 🎯 Overview

This project provides a complete end-to-end solution for collecting, storing, and analyzing sensor data with a focus on EMF (Electromagnetic Field) monitoring. The system consists of:

1. **Flutter Mobile App** - Real-time sensor data collection (GPS, Magnetometer, Accelerometer)
2. **Firebase Realtime Database** - Cloud storage and synchronization
3. **Python Web Dashboard** - Data visualization, EMF mapping, and analytics
4. **Google Fit API Integration** - Heart rate correlation analysis (upcoming)

### Use Cases

- 🌍 **Environmental Monitoring** - Track EMF hotspots in urban environments
- 🏥 **Health Research** - Correlate EMF exposure with physiological responses
- 🗺️ **Urban Planning** - Identify high EMF areas for city planning
- 📊 **Data Fusion** - Combine sensor data with health metrics
- 🔬 **Research & Analysis** - Advanced analytics and pattern recognition

## ✨ Features

### Mobile App (Flutter)
- ✅ Real-time GPS location tracking
- ✅ Magnetometer data collection (EMF readings)
- ✅ Live data visualization
- ✅ Firebase cloud synchronization
- ✅ CSV export functionality
- ✅ Interactive charts and graphs
- ✅ Multiple session management

### Web Dashboard (Python)
- ✅ EMF heatmap visualization with Folium
- ✅ Route tracking and replay
- ✅ Sensor data analytics
- ✅ Real-time data updates
- ✅ Multi-user session support
- ✅ Google Fit integration (planned)
- ✅ Export capabilities

### Data Analysis
- ✅ EMF magnitude calculations
- ✅ Location-based EMF mapping
- ✅ Statistical analysis
- ✅ Time-series visualization
- ✅ Correlation analysis

## 🏗️ Architecture

```
┌─────────────────┐
│  Flutter App    │
│  (Mobile)       │
│                 │
│  • GPS Data     │
│  • Magnetometer │
│  • Timestamp    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│    Firebase     │
│  Realtime DB    │
│                 │
│  • Sessions     │
│  • Location     │
│  • Sensor Data  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Web Dashboard   │
│  (Python)       │
│                 │
│  • EMF Maps     │
│  • Analytics    │
│  • Export       │
└─────────────────┘
```

## 📁 Project Structure

```
App/
├── flutter_app/                      # Flutter mobile application
│   ├── lib/
│   │   ├── main.dart                 # Main app entry point
│   │   ├── chart.dart                # Data visualization charts
│   │   └── widgets/                  # Custom widgets
│   ├── android/                      # Android configuration
│   ├── ios/                          # iOS configuration
│   └── pubspec.yaml                  # Flutter dependencies
│
├── web_dashboard/                    # Python web dashboard
│   ├── utils/
│   │   ├── route_visualizer.py       # Folium map generation
│   │   ├── firebase_client.py        # Firebase integration (planned)
│   │   ├── emf_calculator.py         # EMF calculations (planned)
│   │   └── map_generator.py          # Map utilities (planned)
│   ├── config/                       # Configuration files
│   ├── templates/                    # HTML templates (planned)
│   ├── static/                       # CSS/JS files (planned)
│   └── requirements.txt              # Python dependencies
│
├── .gitignore                        # Git ignore rules
└── README.md                         # This file
```

## 🔧 Prerequisites

### For Flutter App
- Flutter SDK (3.x or higher)
- Dart SDK (3.x or higher)
- Android Studio / Xcode
- Android device or emulator
- Google Firebase account

### For Web Dashboard
- Python 3.8 or higher
- pip (Python package manager)
- Virtual environment (recommended)

### Required Accounts
- Firebase account
- Google Fit API credentials (for heart rate integration)

## 🚀 Installation

### 1. Clone the Repository

```bash
git clone <your-repo-url>
cd "Urban Computing /Assignment 2/App"
```

### 2. Flutter App Setup

```bash
# Navigate to Flutter app directory
cd flutter_app

# Get dependencies
flutter pub get

# Run on connected device
flutter run
```

### 3. Web Dashboard Setup

```bash
# Navigate to web dashboard directory
cd web_dashboard

# Create virtual environment (recommended)
python3 -m venv venv

# Activate virtual environment
# On macOS/Linux:
source venv/bin/activate
# On Windows:
# venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

## ⚙️ Configuration

### Firebase Setup

1. **Create Firebase Project**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Create a new project
   - Enable Realtime Database

2. **Add Android App**
   - Click "Add app" → Android
   - Package name: `com.example.sensor_data_logging_new`
   - Download `google-services.json`
   - Place in: `flutter_app/android/app/google-services.json`

3. **Realtime Database Rules**
   ```json
   {
     "rules": {
       ".read": true,
       ".write": true
     }
   }
   ```
   ⚠️ **Note:** For production, implement proper security rules.

### Flutter App Configuration

Update Firebase configuration in `flutter_app/lib/main.dart`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}
```

## 📱 Usage

### Mobile App

1. **Connect Android Device**
   ```bash
   cd flutter_app
   flutter devices
   flutter run -d <device-id>
   ```

2. **Grant Permissions**
   - Location permissions
   - Storage permissions (for CSV export)

3. **Record Data**
   - Click "Start Recording"
   - Move around to collect data
   - Click "Stop Recording"
   - View charts or export CSV

4. **View Data**
   - "View Charts" - Interactive visualizations
   - "Export CSV" - Save data locally

### Web Dashboard

```bash
cd web_dashboard

# Run the route visualizer
python utils/route_visualizer.py

# This will generate:
# - route_map_<session_id>.html (Interactive map)
# - sensor_analysis_<session_id>.png (Analytics charts)
```

## 📊 Data Flow

1. **Data Collection** (Mobile App)
   - GPS location (lat, lon, altitude, speed, heading)
   - Magnetometer (X, Y, Z in μT)
   - Timestamp for synchronization

2. **Cloud Storage** (Firebase)
   - Real-time data upload
   - Session management
   - Multi-user support

3. **Data Processing** (Web Dashboard)
   - Fetch from Firebase
   - Calculate EMF magnitude: `√(x² + y² + z²)`
   - Generate visualizations
   - Export reports

## 🔥 Firebase Setup (Detailed)

### 1. Project Creation
```
Firebase Console → Create Project
  ├── Project Name: sensor-data-logger
  ├── Analytics: Enabled
  └── Location: Choose region
```

### 2. Add Android App
```
Firebase Console → Project Settings → Add App
  ├── Platform: Android
  ├── Package: com.example.sensor_data_logging_new
  ├── App nickname: Sensor Data Logger
  └── Download: google-services.json
```

### 3. Database Setup
```
Firebase Console → Realtime Database
  ├── Create Database
  ├── Location: us-central1
  ├── Security Rules: Start in test mode
  └── Enable: Realtime Database
```

### 4. Database Structure
```
/sessions/
  └── {session_id}/
      ├── timestamp: "2024-01-15T10:30:00Z"
      ├── status: "recording" | "completed"
      ├── locationData/
      │   └── {push_id}/
      │       ├── seconds: 0.0
      │       ├── latitude: 53.3498
      │       ├── longitude: -6.2603
      │       ├── altitude: 10.5
      │       ├── velocity: 0.5
      │       ├── direction: 45.0
      │       └── horizAcc: 5.0
      └── magnetometerData/
          └── {push_id}/
              ├── seconds: 0.0
              ├── x: 25.3
              ├── y: -12.1
              └── z: 45.7
```

### 🔐 Per-user storage & rules (now enabled)

The app signs in anonymously and writes data under `users/{uid}/sessions/{sessionId}`. Apply these rules so each user can only read/write their own data:

1) Open Firebase Console → Realtime Database → Rules → Edit
2) Paste the contents of `firebase_database.rules.json` from the repo and Publish

Verify:
- Start a recording in the app
- In Data tab, expand `users/{your-uid}/sessions/{sessionId}`
- Live `locationData` and `magnetometerData` should appear

