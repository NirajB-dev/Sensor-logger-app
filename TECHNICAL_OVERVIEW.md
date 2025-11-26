# EMF Sensing Platform – Technical Overview

This document explains the system mathematically, theoretically, and functionally: how the mobile app collects data, how it is stored, and how the web dashboard renders and analyzes it.

## 1) System Architecture

- Mobile app: Flutter (Android) collects Location + Magnetometer + Weather (Open‑Meteo) and uploads to Firebase Realtime Database. Optional: Google Fit heart‑rate/steps.
- Cloud: Firebase Realtime Database stores per‑user, per‑session timeseries.
- Web dashboard: React + Vite + Leaflet. Three views:
  - Live: route polyline + EMF intensity zones + weather markers for a selected session
  - Heatmap (All Sessions): aggregates all sessions, renders intensity heatmap
  - Zones (All Sessions): choropleth‑style grid from aggregated points

## 2) Data Model (Firebase)

All paths are per user and per session.

```
users/{uid}/sessions/{sessionId}/
  timestamp: ISO8601
  status: recording|completed
  locationData: [ { seconds, latitude, longitude, altitude, velocity, direction, horizAcc } ]
  magnetometerData: [ { seconds, x, y, z } ]
  openWeather: [ { ts, lat, lon, temp, humidity, wind_ms, pressure_hpa, ... } ]
  googleFit:
    heartRate: [ { timestamp, heartRate } ]
    steps: [ { timestamp, steps } ]
```

Notes
- `seconds` is the elapsed time from session start (float). This provides a stable time base on device without relying on wall‑clock drift.
- Weather points include geo + timestamp and are sampled every ~60s or after >100 m movement.

## 3) Sensing and Units

- Magnetometer: raw X,Y,Z axes in microtesla (µT). Typical Earth’s field at mid‑latitudes ≈ 25–65 µT. Handset magnetometers may include device bias; the system looks at magnitude trends rather than absolute calibration.
- GPS: WGS‑84 latitude/longitude (degrees), altitude (m), horizontal accuracy when available (m). Speed and course come from the provider when available.
- Weather: Open‑Meteo current weather snapshot – temperature (°C), wind (m/s), pressure (hPa), precipitation (mm/h), cloud cover (%), weather code.

## 4) Math – EMF Magnitude

Given a magnetometer sample `(x, y, z)` in µT, the total field magnitude is the Euclidean norm:

\[ |B| = \sqrt{x^2 + y^2 + z^2} \quad (\mu T) \]

This is used for color thresholds and for heatmap weighting.

## 5) Pairing EMF to Location (Live view)

- Each EMF sample is mapped to the nearest location sample in time.
- Implementation: for incoming EMF point time `t`, find nearest location point time `t_l` with `|t - t_l| ≤ Δt` (default Δt = 2–5 s). If none found, the EMF point is skipped.
- GPS accuracy filter: location points with very poor accuracy (e.g., `horizAcc > 50 m`) can be excluded from the path and pairing.

## 6) Visualization – Live View

- Route: polyline of filtered location points.
- EMF intensity zones: translucent circles centered at matched locations. Circle radius scales with magnitude:

\[ r_m = \mathrm{clamp}(r_{min}, k \cdot |B|, r_{max}) \]

Where `k` is a scale factor in m/µT (e.g., 1.5–2.0), and `r_min, r_max` are bounds (e.g., 15–80 m). Circle color uses thresholds (default):
- Green: |B| < 45 µT
- Orange: 45–70 µT
- Red: > 70 µT

Opacity is low (3–8%) to avoid over‑darkening from overlaps.

- Weather markers: emoji icon at `(lat, lon)`. Popup shows temp, humidity, wind, clouds, rain, timestamp.

## 7) Visualization – Heatmap (All Sessions)

Aggregates all sessions into a continuous heatmap:

- Data loading: reads `users/*/sessions/*/(locationData, magnetometerData)` and converts Firebase objects to arrays; sorts by `seconds`.
- Pairing for aggregation: nearest‑in‑time mapping (within 5 s) per session.
- Weight for each (lat, lon):

\[ w = \min\{1, \max\{0, |B| / 100\}\} \]

- Rendering: Leaflet.heat with large `radius` and `blur` and a multi‑stop gradient (green → yellow → orange → red) to form smooth regional blobs.

## 8) Visualization – Zones (All Sessions)

City‑wide choropleth‑style view derived from aggregated points:

- Grid binning: geographic grid (≈1 km) with cell size \(\Delta \phi = \Delta \lambda = 0.01\) degrees (coarse but adequate for city scale).
- For each cell, compute average weight \(\bar{w} = \frac{1}{N}\sum w_i\).
- Color map:
  - Green (low), Yellow (>0.35), Orange (>0.5), Red (>0.7)
- Cells are drawn as Leaflet rectangles with partial opacity; popups show average and sample count.

This produces a coverage map similar to reference zoning images and is robust to sparse sampling.

## 9) Weather Integration (Open‑Meteo)

- Query URL example (no API key):

```
https://api.open-meteo.com/v1/forecast?latitude=LAT&longitude=LON&current_weather=true&temperature_unit=celsius&windspeed_unit=ms&precipitation_unit=mm&timezone=auto
```

- The mobile app fetches on start and then every ~60 s or after >100 m displacement.
- Stored under `openWeather` with the location used for the query.

## 10) Optional Google Fit Integration

- OAuth via `google_sign_in` (Android). Scopes include activity/body/location read.
- Endpoints: Google Fit Aggregate API (`/users/me/dataset:aggregate`) for `com.google.heart_rate.bpm` and `com.google.step_count.delta` in 1‑minute buckets.
- Stored under `googleFit/heartRate` and `googleFit/steps` with timestamps.

## 11) CSV Export

- Device storage export merges location + magnetometer + weather series into a tabular CSV with timestamps (seconds since session start and ISO time where applicable).
- Export path uses application documents directory for reliability on modern Android.

## 12) Security and Multi‑Tenancy

Firebase rules (per user isolation):

```
{
  "rules": {
    "users": {
      "$uid": {
        ".read": "$uid === auth.uid",
        ".write": "$uid === auth.uid"
      }
    },
    "sessions": { ".read": false, ".write": false }
  }
}
```

The app signs in anonymously and writes only under `users/{uid}`.

## 13) Correlation Analysis (Concept)

For a session, create aligned time windows (e.g., 60 s). Compute window means of `|B|` and traffic/heart‑rate, then compute correlation.

- Pearson correlation (linear):

\[ r = \frac{\sum (B_i - \bar{B})(T_i - \bar{T})}{\sqrt{\sum (B_i-\bar{B})^2}\,\sqrt{\sum (T_i-\bar{T})^2}} \]

- Spearman rank (monotonic) can be used if distributions are non‑Gaussian or contain outliers.

## 14) Design Choices and Trade‑offs

- Index vs time pairing: live uses nearest‑time with short window; aggregation also uses time to avoid drift across streams.
- Accuracy filter: reduces visual noise but can hide data in poor GPS reception; thresholds are adjustable.
- Opacity and circle radius: tuned to stay readable at city zoom. Heatmap/zone views are better for city‑scale comparisons.
- Heatmap vs Zones: heatmap shows continuous density; zones show interpretable regions and are easier to compare between days.

## 15) Extensibility

- Traffic open data: plug a GeoJSON/CSV URL and render speed/flow markers or tiles; snap to route for correlation.
- Thresholds, bin size, and styles are constants in the dashboard (`App.tsx`) and can be tuned per domain.
- Add analytics (server/cloud functions or client‑side) to compute summaries per session or per region.

## 16) Known Limitations

- Phone magnetometers are susceptible to device orientation/bias and local ferromagnetic materials; magnitude reduces orientation dependence but not all artifacts.
- Heatmap weight normalization (|B|/100) is heuristic; re‑scale for your data distribution (e.g., using percentiles).
- Grid cells use fixed degree size (≈1 km at Dublin lat). For more accurate area, use a projected grid (e.g., EPSG:3857 meters) or H3 indexing.

## 17) Quick Operational Flow

1. Start recording → app authenticates anonymously → new session created.
2. Streams: location, magnetometer, weather; writes in real‑time to Firebase under the session path.
3. Live dashboard subscribes to that session and updates immediately.
4. Stop recording → session status saved; view heatmap/zones to compare with all sessions.
5. Export CSV or fetch Google Fit data to analyze physiological correlation.

---
This document covers the math behind EMF magnitude and the visualizations, the data structures and synchronization, and the functional behaviors across mobile and web. Adjust constants (thresholds, radii, grid size) to fit your target analysis and geography.
