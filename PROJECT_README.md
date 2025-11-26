# EMF Sensor Data Logger & Analytics Dashboard

> **A comprehensive mobile sensor data collection and visualization system for EMF (Electromagnetic Field) monitoring with real-time analytics.**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev/)
[![React](https://img.shields.io/badge/React-18.x-blue.svg)](https://react.dev/)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.x-blue.svg)](https://www.typescriptlang.org/)
[![Firebase](https://img.shields.io/badge/Firebase-Realtime-orange.svg)](https://firebase.google.com/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## 🎯 Overview

This project provides a complete end-to-end solution for collecting, storing, and analyzing sensor data with a focus on EMF (Electromagnetic Field) monitoring. The system consists of:

- **📱 Flutter Mobile App**: Cross-platform app for real-time sensor data collection
- **🌐 React Web Dashboard**: Interactive web interface for data visualization and analysis
- **🔥 Firebase Backend**: Real-time database for data storage and synchronization
- **📊 Analytics Tools**: Advanced visualization with heatmaps, zones, and live tracking

## ✨ Features

### Mobile App (Flutter)
- 📡 **Real-time EMF/Magnetometer data collection**
- 🌍 **GPS location tracking** with high accuracy
- 🌤️ **Weather data integration** via OpenWeather API
- ❤️ **Heart rate monitoring** (Google Fit integration)
- 🔄 **Real-time Firebase synchronization**
- 📊 **Live data visualization** with charts
- 🎛️ **Configurable sampling rates**
- 📱 **Cross-platform** (Android/iOS)

### Web Dashboard (React/TypeScript)
- 🗺️ **Interactive Leaflet maps** with real-time updates
- 🔥 **Heatmap visualization** for EMF intensity zones  
- 📍 **Live session tracking** with GPS routes
- 🌦️ **Weather overlay** with meteorological data
- 📊 **Multi-session analysis** and comparison
- 🎨 **Multiple visualization modes**:
  - Live tracking view
  - Aggregated heatmaps
  - Grid-based zone analysis
- ⚡ **Real-time data streaming** from Firebase

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│   Flutter App   │───▶│   Firebase       │◀───│   React Dashboard   │
│                 │    │   Realtime DB    │    │                     │
│ • Sensors       │    │                  │    │ • Interactive Maps  │
│ • GPS           │    │ • User Sessions  │    │ • Data Analytics    │
│ • Weather API   │    │ • Sensor Data    │    │ • Visualizations    │
│ • Heart Rate    │    │ • Metadata       │    │ • Real-time Updates │
└─────────────────┘    └──────────────────┘    └─────────────────────┘
```

## 📂 Project Structure

```
├── flutter_app/                 # Mobile application
│   ├── lib/
│   │   ├── main.dart           # App entry point
│   │   ├── google_fit_service.dart  # Heart rate integration
│   │   └── chart.dart          # Data visualization
│   ├── android/                # Android-specific configs
│   └── ios/                    # iOS-specific configs
│
├── web_dashboard/              # Web analytics dashboard
│   ├── src/
│   │   ├── ui/App.tsx         # Main dashboard component
│   │   ├── firebase.ts        # Firebase configuration
│   │   └── main.tsx           # React app entry
│   ├── package.json           # Dependencies
│   └── tsconfig.json          # TypeScript config
│
├── docs/                      # Documentation
│   ├── SETUP.md              # Setup instructions
│   ├── TECHNICAL_OVERVIEW.md # Technical details
│   └── GOOGLE_FIT_SETUP.md   # Heart rate setup guide
│
└── README.md                  # This file
```

## 🚀 Quick Start

### Prerequisites
- Flutter SDK (3.0+)
- Node.js (18+)
- Firebase account
- OpenWeather API key

### 1. Clone Repository
```bash
git clone https://github.com/NirajB-dev/Sensor-logger-app.git
cd Sensor-logger-app
```

### 2. Flutter App Setup
```bash
cd flutter_app
flutter pub get
# Add your google-services.json (Android) / GoogleService-Info.plist (iOS)
flutter run
```

### 3. Web Dashboard Setup
```bash
cd web_dashboard
npm install
# Configure Firebase in src/firebase.ts
npm run dev
```

### 4. Firebase Configuration
1. Create a Firebase project
2. Enable Realtime Database
3. Add your config to both apps
4. Set up authentication (optional)

## 📊 Data Collection

### Sensor Data Types
- **Magnetometer**: X, Y, Z magnetic field values (μT)
- **GPS**: Latitude, longitude, altitude, accuracy
- **Weather**: Temperature, humidity, pressure, wind
- **Heart Rate**: BPM data from Google Fit
- **Metadata**: Timestamps, session info, device details

### Data Structure
```typescript
interface Session {
  id: string
  timestamp: string
  status: 'active' | 'completed'
  totalSamples: number
  locationData: LocationPoint[]
  magnetometerData: MagnetometerPoint[]
  weatherPoints: WeatherPoint[]
}
```

## 🗺️ Visualization Features

### Live Tracking Mode
- Real-time GPS route visualization
- EMF intensity zones with color coding
- Weather data overlays
- Session statistics

### Heatmap Analysis
- Aggregated data from all sessions
- Intensity gradients (Green → Yellow → Red)
- Configurable radius and blur settings
- Temporal analysis capabilities

### Zone Classification
- Grid-based spatial analysis
- Average EMF intensity per zone
- Statistical summaries
- Comparative analysis tools

## 🛠️ Technical Details

### Mobile App Technologies
- **Flutter**: Cross-platform development
- **Dart**: Programming language
- **Firebase SDK**: Real-time data sync
- **Geolocator**: GPS functionality
- **Sensors Plus**: Hardware sensor access
- **HTTP**: Weather API integration

### Web Dashboard Technologies
- **React 18**: UI framework
- **TypeScript**: Type-safe development
- **Leaflet**: Interactive maps
- **Leaflet.heat**: Heatmap visualizations
- **Firebase Web SDK**: Real-time database
- **Vite**: Build tool and dev server

## 📱 Mobile App Features

### Data Collection
- Configurable sampling rates (1-10 seconds)
- Battery optimization
- Background data collection
- Offline data caching
- Auto-upload when connected

### User Interface
- Real-time sensor readings
- Interactive charts
- Session management
- Export functionality
- Settings and preferences

## 🌐 Web Dashboard Features

### Interactive Maps
- Leaflet.js integration
- OpenStreetMap tiles
- Real-time data overlays
- Multiple visualization layers

### Data Analysis
- Multi-session comparison
- Statistical analysis
- Export capabilities
- Filtering and search

## 🔧 Configuration

### Environment Variables
```bash
# Web Dashboard (.env)
VITE_FIREBASE_API_KEY=your_api_key
VITE_FIREBASE_AUTH_DOMAIN=your_auth_domain
VITE_FIREBASE_DATABASE_URL=your_database_url
VITE_FIREBASE_PROJECT_ID=your_project_id

# Flutter App
# Configure in firebase_options.dart (auto-generated)
```

### Firebase Rules
```json
{
  "rules": {
    "users": {
      "$userId": {
        ".read": true,
        ".write": true
      }
    }
  }
}
```

## 📈 Performance

### Mobile App
- Optimized for battery life
- Efficient data compression
- Smart sampling strategies
- Memory management

### Web Dashboard
- Real-time updates with minimal bandwidth
- Efficient data aggregation
- Responsive design
- Progressive loading

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Support

For questions or support, please:
- Open an issue on GitHub
- Check the documentation in `/docs`
- Review the setup guides

## 🎯 Use Cases

- **Urban EMF Mapping**: City-wide electromagnetic field monitoring
- **Environmental Research**: Academic and scientific studies
- **Health Studies**: EMF exposure correlation with health metrics
- **IoT Deployments**: Smart city sensor network development
- **Educational Projects**: Learning about sensor data collection

---

**Built with ❤️ for Urban Computing & Environmental Monitoring**
