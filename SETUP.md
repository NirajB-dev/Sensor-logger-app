# Quick Setup Guide

This guide will help you get the EMF Sensor Data Logger up and running quickly.

## 🚀 Quick Start

### 1. Firebase Setup (5 minutes)

#### Android App Configuration

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project called "sensor-data-logger" (or use existing)
3. Click "Add app" → Android
4. Package name: `com.example.sensor_data_logging_new`
5. Download `google-services.json`
6. Place it in: `flutter_app/android/app/google-services.json`

#### Web Dashboard Configuration

1. In the same Firebase project, click "Add app" → Web (</> icon)
2. Register your web app (name it "EMF Dashboard" or similar)
3. Copy the Firebase configuration values
4. Create a `.env` file in `web_dashboard/` directory:

```bash
cd web_dashboard
cp env.example .env
```

5. Edit `.env` and fill in your Firebase web config:
```
VITE_FIREBASE_API_KEY=your_api_key_here
VITE_FIREBASE_AUTH_DOMAIN=your_project.firebaseapp.com
VITE_FIREBASE_DB_URL=https://your_project-default-rtdb.firebaseio.com/
VITE_FIREBASE_PROJECT_ID=your_project_id
VITE_FIREBASE_STORAGE_BUCKET=your_project.appspot.com
VITE_FIREBASE_SENDER_ID=your_sender_id
VITE_FIREBASE_APP_ID=your_app_id
```

### 2. Run Flutter App (2 minutes)

```bash
cd flutter_app
flutter pub get
flutter run
```

**Note:** Make sure you have:
- An Android device connected via USB (enable USB debugging)
- Or an Android emulator running
- Check available devices: `flutter devices`

### 3. Run Web Dashboard (2 minutes)

```bash
cd web_dashboard
npm install
npm run dev
```

The web dashboard will open at **http://localhost:5173**

**Note:** Make sure you have:
- Node.js 16+ installed
- `.env` file configured with Firebase web credentials

## ✅ That's It!

Your app is now running and ready to collect sensor data!

## 📱 First Recording

1. Click "Start Recording" in the app
2. Walk around for 30 seconds
3. Click "Stop Recording"
4. View your data on the interactive charts
5. Export CSV for further analysis

## 🔧 Troubleshooting

### Flutter Issues
- **No devices found**: Run `flutter devices` to see available devices
  - For Android: Enable USB debugging on your phone
  - For emulator: Run `flutter emulators` to list and start emulators
- **Location permissions**: Grant location permissions when prompted on your device
- **Firebase errors**: Verify `google-services.json` is in `flutter_app/android/app/`
- **Build errors**: Try `flutter clean` then `flutter pub get` and rebuild

### Web Dashboard Issues
- **Port already in use**: Change port in `package.json` or kill the process using port 5173
- **Firebase errors**: Verify `.env` file exists and has correct Firebase web config values
- **Module not found**: Run `npm install` to install dependencies
- **Map not loading**: Check browser console for errors, verify Firebase config

## 📚 Next Steps

- Read the full [README.md](README.md) for detailed documentation
- Check [TECHNICAL_OVERVIEW.md](TECHNICAL_OVERVIEW.md) for system architecture
- Explore Firebase console for data visualization
- View live data on the web dashboard at http://localhost:5173
- Integrate Google Fit API (see [GOOGLE_FIT_SETUP.md](GOOGLE_FIT_SETUP.md))

## 💡 Tips

- **First run**: Start with short recording sessions (30-60 seconds)
- **Data collection**: Move around to collect diverse location data
- **GPS accuracy**: Check GPS accuracy indicator in the app (aim for <50m)
- **Data export**: Export CSV files for backup and analysis
- **Live monitoring**: Keep the web dashboard open to see data appear in real-time
- **Multiple sessions**: Each recording creates a new session in Firebase

## 📋 Prerequisites

- **Flutter**: Flutter SDK 3.0+ installed ([Install Flutter](https://flutter.dev/docs/get-started/install))
- **Node.js**: Node.js 16+ and npm installed ([Install Node.js](https://nodejs.org/))
- **Android**: Android Studio with Android SDK (for mobile app)
- **Firebase**: Firebase account and project created
- **Device**: Android device with USB debugging enabled OR Android emulator

---

Need help? Check the [README.md](README.md) or open an issue on GitHub.
