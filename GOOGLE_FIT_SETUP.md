# Google Fit Integration Setup Guide

## Step 1: Google Cloud Console Setup

1. **Go to Google Cloud Console**: https://console.cloud.google.com/
2. **Create/Select Project**: Create a new project or select existing one
3. **Enable APIs**:
   - Go to "APIs & Services" → "Library"
   - Search and enable:
     - **Fitness API**
     - **Google Fit REST API**
4. **Create OAuth Credentials**:
   - Go to "APIs & Services" → "Credentials"
   - Click "Create Credentials" → "OAuth 2.0 Client ID"
   - Application type: "Android"
   - Package name: `com.example.sensor_data_logging`
   - SHA-1 fingerprint: Get from `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`

## Step 2: Configure Android App

Add to `android/app/build.gradle`:
```gradle
android {
    defaultConfig {
        // ... existing config
        manifestPlaceholders = [
            'GOOGLE_FIT_CLIENT_ID': 'YOUR_CLIENT_ID_HERE'
        ]
    }
}
```

Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data
    android:name="com.google.android.gms.version"
    android:value="@integer/google_play_services_version" />
```

## Step 3: Usage

1. **Run the app**: `flutter run`
2. **Connect Google Fit**: Tap "Connect Google Fit" button
3. **Authorize**: Grant permissions for fitness data access
4. **Fetch Data**: Tap "Fetch Health Data" to get heart rate and steps
5. **View in Dashboard**: Data appears in Firebase and web dashboard

## Step 4: Data Structure

Google Fit data is stored in Firebase under:
```
users/{userId}/sessions/{sessionId}/googleFit/
├── heartRate: [{timestamp, heartRate}, ...]
├── steps: [{timestamp, steps}, ...]
└── lastUpdated: ISO timestamp
```

## Features

- **Heart Rate**: BPM readings from Google Fit
- **Step Count**: Step data from Google Fit  
- **Real-time Sync**: Data syncs to Firebase
- **Correlation Analysis**: Link EMF exposure to physiological responses
- **Web Dashboard**: View health data alongside EMF readings

## Troubleshooting

- **Authentication fails**: Check OAuth client ID and package name
- **No data**: Ensure Google Fit app has heart rate/step permissions
- **API errors**: Verify Fitness API is enabled in Google Cloud Console

