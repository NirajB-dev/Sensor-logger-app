# EMF Sensing Platform 📡

A comprehensive real-time EMF (Electromagnetic Field) monitoring system built for urban computing research. This platform combines mobile sensing with cloud analytics to visualize electromagnetic field distributions across urban environments.

## 🌟 Features

### 📱 **Flutter Mobile App**
- **Real-time EMF Detection**: Uses device magnetometer to measure electromagnetic fields (μT)
- **GPS Route Tracking**: High-accuracy location logging with filtering
- **Weather Integration**: Automatic weather data collection via Open-Meteo API
- **Heart Rate Monitoring**: Google Fit integration for physiological data correlation
- **Live Data Streaming**: Real-time upload to Firebase Realtime Database
- **EMF Community Map**: Interactive map showing EMF zones with performance optimization
- **Fun EMF Reader**: Handheld device simulation with haptic feedback
- **Data Export**: CSV export functionality for research analysis

### 🌐 **Web Dashboard**
- **Live Session Monitoring**: Real-time visualization of active data collection
- **Interactive Maps**: Three specialized views for different analysis needs
  - **Live View**: Individual session routes with EMF intensity zones
  - **Heatmap View**: Aggregated EMF data across all sessions
  - **Territory View**: Grid-based choropleth visualization
- **Professional UI**: Custom PNG icons and modern design
- **Heart Rate Integration**: Physiological data overlay on environmental data
- **Weather Data Display**: Comprehensive weather information with location context

## 🚀 **Live Demo**
- **Web Dashboard**: [https://webdashboard-e7wbs9yqn-nirajs-projects-71861c1e.vercel.app](https://webdashboard-e7wbs9yqn-nirajs-projects-71861c1e.vercel.app)

## 🏗️ **Architecture**

```
📱 Flutter Mobile App
    ├── EMF Detection (Magnetometer)
    ├── GPS Tracking
    ├── Weather API Integration
    ├── Google Fit Heart Rate
    └── Firebase Realtime DB Upload
    
☁️ Firebase Cloud
    ├── Realtime Database
    ├── Authentication
    └── Security Rules
    
🌐 React Web Dashboard
    ├── Live Session Monitoring
    ├── Heatmap Visualization
    ├── Territory Analysis
    └── Data Analytics
```

## 📊 **Technical Specifications**

### **EMF Measurement**
- **Sensor**: Device magnetometer (3-axis)
- **Units**: Microtesla (μT)
- **Formula**: `|B| = √(x² + y² + z²)`
- **Typical Range**: 25-65 μT (Earth's magnetic field)
- **Risk Thresholds**: 
  - 🟢 Safe: < 45 μT
  - 🟡 Moderate: 45-70 μT
  - 🔴 High Risk: > 70 μT

### **Data Collection**
- **Location**: WGS-84 GPS with accuracy filtering
- **Sampling Rate**: ~1-2 Hz for sensors
- **Weather**: Open-Meteo API (no key required)
- **Sync**: Real-time Firebase streaming
- **Storage**: Per-user, per-session timeseries

## 🛠️ **Setup & Installation**

### **Prerequisites**
- Flutter 3.35.6+
- Android Studio / Xcode
- Node.js 18+
- Firebase account

### **Mobile App Setup**
```bash
cd flutter_app
flutter pub get
# Configure Firebase (see SETUP.md)
flutter run
```

### **Web Dashboard Setup**
```bash
cd web_dashboard
npm install
# Add Firebase config to .env
npm run dev
```

### **Deployment**
```bash
# Web Dashboard to Vercel
cd web_dashboard
vercel --prod
```

## 📱 **Mobile App Features**

### **Core Functionality**
- **Session Management**: Start/stop data collection
- **Multi-sensor Logging**: Location + Magnetometer + Weather
- **Real-time Visualization**: Live EMF map with zone clustering
- **Performance Optimized**: Smart data sampling and spatial clustering
- **Export Capabilities**: CSV export for research analysis

### **EMF Map Optimizations**
- **Spatial Clustering**: Groups nearby readings into ~100m grid cells
- **Smart Sampling**: Adaptive sampling based on data density
- **Risk-based Visualization**: Color-coded zones for different EMF levels
- **Zoom-responsive**: Dynamic sizing based on map zoom level
- **Performance**: 70-85% faster loading with clustering

### **Fun EMF Reader**
- **Visual Design**: Retro handheld device appearance
- **Real-time Updates**: Live EMF magnitude display
- **Haptic Feedback**: Physical response to EMF levels
- **Animations**: Smooth transitions and visual effects

## 🌐 **Web Dashboard Features**

### **Live Session View**
- Route polylines with GPS accuracy filtering
- EMF intensity zones as translucent circles
- Weather markers with detailed popups
- Heart rate integration from Google Fit

### **Heatmap View**
- Aggregates data from all sessions
- Continuous density visualization
- Multi-stop color gradient (green → yellow → orange → red)
- Leaflet.heat rendering with performance optimization

### **Territory View**
- Grid-based choropleth analysis
- ~1km geographic cells
- Statistical aggregation (average EMF per cell)
- Color-coded risk assessment

## 🔬 **Scientific Applications**

### **Research Use Cases**
- Urban EMF exposure mapping
- Environmental health studies
- Correlation with physiological data
- Traffic/infrastructure impact analysis
- Public health awareness

### **Data Analysis**
- Correlation analysis (Pearson/Spearman)
- Temporal pattern recognition
- Spatial clustering analysis
- Multi-variate environmental correlation

## 🎨 **UI/UX Design**

### **Mobile App**
- **Material Design**: Modern Android design patterns
- **Custom Components**: Specialized EMF visualization widgets
- **Performance Focused**: Optimized for real-time data display
- **Accessibility**: Clear visual indicators and haptic feedback

### **Web Dashboard**
- **Dark Theme**: Professional analytics appearance
- **Interactive Maps**: Leaflet-based with custom controls
- **Real-time Updates**: Live data streaming and visualization
- **Professional Icons**: Custom PNG iconography
- **Responsive Design**: Works across different screen sizes

## 🔧 **Technical Implementation**

### **Mobile Technology Stack**
- **Framework**: Flutter 3.35.6
- **Backend**: Firebase Realtime Database
- **Maps**: flutter_map with OpenStreetMap
- **Sensors**: Native Android sensor APIs
- **Authentication**: Firebase Anonymous Auth
- **APIs**: Open-Meteo, Google Fit

### **Web Technology Stack**
- **Framework**: React 18 + TypeScript
- **Build**: Vite 5
- **Maps**: Leaflet + Leaflet.heat
- **Backend**: Firebase Realtime Database
- **Deployment**: Vercel
- **Icons**: Custom PNG assets

### **Performance Optimizations**
- **Spatial clustering**: 80-90% reduction in render objects
- **Smart sampling**: Adaptive data reduction
- **Early filtering**: Client-side data optimization
- **Caching**: Efficient state management
- **Progressive loading**: Staged data visualization

## 📁 **Project Structure**

```
📁 flutter_app/          # Mobile application
   ├── 📁 lib/
   │   ├── 📁 screens/    # UI screens
   │   ├── 📁 widgets/    # Reusable components
   │   └── 📁 services/   # Data services
   └── 📁 android/        # Android configuration

📁 web_dashboard/         # Web dashboard
   ├── 📁 src/
   │   ├── 📁 ui/         # React components
   │   └── 📄 firebase.ts # Firebase configuration
   └── 📁 public/icons/   # Custom PNG icons

📄 TECHNICAL_OVERVIEW.md  # Detailed technical documentation
📄 SETUP.md              # Setup instructions
📄 firebase_database.rules.json # Security rules
```

## 🤝 **Contributing**

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 **Acknowledgments**

- **Open-Meteo**: Free weather API service
- **Firebase**: Real-time database and authentication
- **Flutter Community**: Mobile development framework
- **Leaflet**: Web mapping library
- **Vercel**: Web hosting and deployment

## 📞 **Contact & Support**

- **Repository**: [Sensor-logger-app](https://github.com/NirajB-dev/Sensor-logger-app)
- **Issues**: GitHub Issues for bug reports and feature requests
- **Documentation**: See [TECHNICAL_OVERVIEW.md](TECHNICAL_OVERVIEW.md) for detailed technical information

---

*Built for Urban Computing Research - Real-time EMF sensing and visualization platform* 🌍📊