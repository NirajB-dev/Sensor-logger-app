import React, { useEffect, useRef, useState } from 'react'
import { ref, onChildAdded, onValue } from 'firebase/database'
import { db } from '../firebase'

interface Session {
  id: string
  timestamp: string
  status: string
  totalSamples?: number
}

interface LocationPoint {
  seconds: number
  latitude: number
  longitude: number
  altitude: number
  velocity: number
  direction: number
  horizAcc: number
}

interface MagnetometerPoint {
  seconds: number
  x: number
  y: number
  z: number
}

interface WeatherPoint {
  ts: string
  lat: number
  lon: number
  temp: number
  humidity: number
  pressure_hpa: number
  wind_ms: number
  wind_deg: number
  rain_1h_mm: number
  clouds_pct: number
  cond?: string
}

export const App: React.FC = () => {
  const mapRef = useRef<any>(null)
  const mapDivRef = useRef<HTMLDivElement | null>(null)
  const [sessions, setSessions] = useState<Session[]>([])
  const [selectedSession, setSelectedSession] = useState<string | null>(null)
  const [locationPoints, setLocationPoints] = useState<LocationPoint[]>([])
  const [magnetometerPoints, setMagnetometerPoints] = useState<MagnetometerPoint[]>([])
  const [weatherPoints, setWeatherPoints] = useState<WeatherPoint[]>([])
  const [emfMappedCount, setEmfMappedCount] = useState<number>(0)
  const [route, setRoute] = useState<'live' | 'heatmap' | 'zones'>(() =>
    location.hash === '#/heatmap' ? 'heatmap' : location.hash === '#/zones' ? 'zones' : 'live'
  )
  const [heatPoints, setHeatPoints] = useState<Array<[number, number, number]>>([]) // [lat, lon, weight]
  const pathLayerRef = useRef<any>(null)
  const markersLayerRef = useRef<any>(null)
  const weatherLayerRef = useRef<any>(null)
  const heatLayerRef = useRef<any>(null)
  const polygonLayerRef = useRef<any>(null)

  // Initialize map
  useEffect(() => {
    if (mapRef.current || !mapDivRef.current) return
    
    const timer = setTimeout(() => {
      const el = mapDivRef.current
      if (!el) return
      
      const map = (window as any).L.map(el).setView([53.3498, -6.2603], 12)
      ;(window as any).L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png').addTo(map)
      
      mapRef.current = map
      console.log('Map initialized')
    }, 100)
    
    return () => {
      clearTimeout(timer)
      if (mapRef.current) mapRef.current.remove()
    }
  }, [])

  // Load sessions from Firebase
  useEffect(() => {
    console.log('Loading sessions from Firebase...')
    const sessionsRef = ref(db, 'users')
    const unsubscribe = onValue(sessionsRef, (snapshot) => {
      const data = snapshot.val()
      console.log('Firebase data received:', data)
      
      if (data) {
        const sessionList: Session[] = []
        Object.keys(data).forEach(userId => {
          const userSessions = data[userId]?.sessions
          if (userSessions) {
            Object.keys(userSessions).forEach(sessionId => {
              sessionList.push({
                id: sessionId,
                timestamp: userSessions[sessionId].timestamp,
                status: userSessions[sessionId].status,
                totalSamples: userSessions[sessionId].totalSamples
              })
            })
          }
        })
        console.log('Sessions found:', sessionList.length)
        setSessions(sessionList.sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime()))
      } else {
        console.log('No data found in Firebase')
      }
    }, (error) => {
      console.error('Firebase error:', error)
    })

    return () => unsubscribe()
  }, [])

  // Simple hash routing: #/live, #/heatmap, #/zones
  useEffect(() => {
    const onHash = () => {
      if (location.hash === '#/heatmap') setRoute('heatmap')
      else if (location.hash === '#/zones') setRoute('zones')
      else setRoute('live')
    }
    window.addEventListener('hashchange', onHash)
    return () => window.removeEventListener('hashchange', onHash)
  }, [])

  // Subscribe to selected session data
  useEffect(() => {
    if (!selectedSession) return

    setLocationPoints([])
    setMagnetometerPoints([])
    setWeatherPoints([])

    // Find the session's user ID
    const sessionsRef = ref(db, 'users')
    onValue(sessionsRef, (snapshot) => {
      const data = snapshot.val()
      if (data) {
        Object.keys(data).forEach(userId => {
          const userSessions = data[userId]?.sessions
          if (userSessions && userSessions[selectedSession]) {
            // Subscribe to location data
            const locationRef = ref(db, `users/${userId}/sessions/${selectedSession}/locationData`)
            onChildAdded(locationRef, (snapshot) => {
              const point = snapshot.val()
              setLocationPoints(prev => [...prev, point])
            })

            // Subscribe to magnetometer data
            const magnetRef = ref(db, `users/${userId}/sessions/${selectedSession}/magnetometerData`)
            onChildAdded(magnetRef, (snapshot) => {
              const point = snapshot.val()
              setMagnetometerPoints(prev => [...prev, point])
            })

            // Subscribe to weather data
            const weatherRef = ref(db, `users/${userId}/sessions/${selectedSession}/openWeather`)
            onChildAdded(weatherRef, (snapshot) => {
              const point = snapshot.val()
              setWeatherPoints(prev => [...prev, point])
            })
          }
        })
      }
    })
  }, [selectedSession])

  // Update map with new data (Live session view)
  useEffect(() => {
    if (route !== 'live') return
    if (!mapRef.current || locationPoints.length === 0) return

    const map = mapRef.current

    // Clear existing layers
    if (pathLayerRef.current) map.removeLayer(pathLayerRef.current)
    if (markersLayerRef.current) map.removeLayer(markersLayerRef.current)
    if (weatherLayerRef.current) map.removeLayer(weatherLayerRef.current)
    if (heatLayerRef.current) { map.removeLayer(heatLayerRef.current); heatLayerRef.current = null }
    if (polygonLayerRef.current) { map.removeLayer(polygonLayerRef.current); polygonLayerRef.current = null }

    // Draw path (filter out very poor GPS accuracy if available)
    const gpsAccuracyThreshold = 50; // meters
    const filteredLocations = locationPoints.filter(p => {
      const acc = Number(p.horizAcc)
      return isNaN(acc) || acc <= gpsAccuracyThreshold
    })
    const pathCoords = filteredLocations.map(p => [p.latitude, p.longitude])
    const pathLayer = (window as any).L.polyline(pathCoords, { color: 'blue', weight: 3 }).addTo(map)
    pathLayerRef.current = pathLayer

    // Add EMF intensity zones (bigger translucent circles by magnitude)
    const markersLayer = (window as any).L.layerGroup().addTo(map)
    // Pair magnetometer reading to nearest-in-time location point
    const locTimes = locationPoints.map(p => p.seconds)
    const maxTimeGapSec = 5; // Increased to 5s to catch more readings
    const findNearestLocation = (tSec: number) => {
      if (locTimes.length === 0) return null
      // binary search for insertion point
      let lo = 0, hi = locTimes.length - 1
      while (lo < hi) {
        const mid = Math.floor((lo + hi) / 2)
        if (locTimes[mid] < tSec) lo = mid + 1; else hi = mid
      }
      const cand1Idx = lo
      const cand2Idx = Math.max(0, lo - 1)
      const cand1 = { idx: cand1Idx, dt: Math.abs(locTimes[cand1Idx] - tSec) }
      const cand2 = { idx: cand2Idx, dt: Math.abs(locTimes[cand2Idx] - tSec) }
      const best = cand1.dt <= cand2.dt ? cand1 : cand2
      return best.dt <= maxTimeGapSec ? locationPoints[best.idx] : null
    }

    // Sample EMF readings to reduce overlap (show every Nth reading if too dense)
    const emfReadingsToShow = magnetometerPoints.length > 200 
      ? magnetometerPoints.filter((_, i) => i % Math.ceil(magnetometerPoints.length / 200) === 0)
      : magnetometerPoints

    let mappedCount = 0
    emfReadingsToShow.forEach((magPoint) => {
      const locationPoint = findNearestLocation(magPoint.seconds)
      if (locationPoint) {
        mappedCount++
        const magnitude = Math.sqrt(magPoint.x**2 + magPoint.y**2 + magPoint.z**2)
        const color = magnitude > 70 ? '#d73027' : magnitude > 45 ? '#fc8d59' : '#1a9850'
        // Radius in meters scaled by magnitude (clamped) - smaller to reduce overlap
        const radiusMeters = Math.max(15, Math.min(80, magnitude * 1.5))

        const zone = (window as any).L.circle([locationPoint.latitude, locationPoint.longitude], {
          radius: radiusMeters,
          color,
          weight: 1,
          fillColor: color,
          fillOpacity: 0.03,
          opacity: 0.2,
          className: 'emf-intensity-zone'
        }).bindPopup(`
          <b>EMF intensity zone</b><br>
          Magnitude: ${magnitude.toFixed(1)} μT<br>
          Time: ${magPoint.seconds.toFixed(1)}s<br>
          Radius: ~${Math.round(radiusMeters)} m
        `)

        markersLayer.addLayer(zone)
      }
    })
    markersLayerRef.current = markersLayer
    
    // Store mapping stats
    setEmfMappedCount(mappedCount)
    
    // Debug: log mapping stats
    console.log(`EMF Mapping Stats:
      Total EMF readings: ${magnetometerPoints.length}
      Shown (after sampling): ${emfReadingsToShow.length}
      Successfully mapped to locations: ${mappedCount}
      Location points available: ${locationPoints.length}
      Filtered location points (accuracy ≤50m): ${filteredLocations.length}`)

    // Add weather markers
    const weatherLayer = (window as any).L.layerGroup().addTo(map)
    weatherPoints.forEach((weatherPoint) => {
      const weatherIcon = (window as any).L.divIcon({
        html: `<div style="
          background: linear-gradient(135deg, #6366F1, #8B5CF6); 
          color: white; 
          border-radius: 50%; 
          width: 32px; 
          height: 32px; 
          display: flex; 
          align-items: center; 
          justify-content: center; 
          font-size: 16px; 
          border: 2px solid white; 
          box-shadow: 0 2px 8px rgba(0,0,0,0.3);
        ">🌤️</div>`,
        className: 'weather-marker',
        iconSize: [32, 32],
        iconAnchor: [16, 16]
      })
      
      const marker = (window as any).L.marker([weatherPoint.lat, weatherPoint.lon], { icon: weatherIcon })
        .bindPopup(`
          <div style="
            background: linear-gradient(180deg, #1A2332 0%, #0F1B2E 100%); 
            color: white; 
            padding: 16px; 
            border-radius: 12px; 
            min-width: 250px;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            border: 1px solid #2A3441;
          ">
            <div style="
              display: flex; 
              align-items: center; 
              gap: 12px; 
              margin-bottom: 16px; 
              padding-bottom: 12px; 
              border-bottom: 1px solid rgba(255,255,255,0.1);
            ">
              <div style="font-size: 24px;">🌤️</div>
              <div>
                <div style="font-weight: 600; font-size: 16px;">Weather Data</div>
                <div style="font-size: 11px; color: #9CA3AF; margin-top: 2px;">
                  ${new Date(weatherPoint.ts).toLocaleString()}
                </div>
              </div>
            </div>
            
            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px;">
              <div style="display: flex; justify-content: space-between; padding: 8px 0;">
                <span style="color: #9CA3AF; font-size: 14px;">Temp:</span>
                <span style="font-weight: 500; font-size: 14px;">${weatherPoint.temp?.toFixed(1) || 'N/A'}°C</span>
              </div>
              <div style="display: flex; justify-content: space-between; padding: 8px 0;">
                <span style="color: #9CA3AF; font-size: 14px;">Pressure:</span>
                <span style="font-weight: 500; font-size: 14px;">${weatherPoint.pressure_hpa || 'N/A'} hPa</span>
              </div>
              <div style="display: flex; justify-content: space-between; padding: 8px 0;">
                <span style="color: #9CA3AF; font-size: 14px;">Humidity:</span>
                <span style="font-weight: 500; font-size: 14px;">${weatherPoint.humidity || 'N/A'}%</span>
              </div>
              <div style="display: flex; justify-content: space-between; padding: 8px 0;">
                <span style="color: #9CA3AF; font-size: 14px;">Wind:</span>
                <span style="font-weight: 500; font-size: 14px;">${weatherPoint.wind_ms?.toFixed(2) || 'N/A'} m/s</span>
              </div>
              <div style="display: flex; justify-content: space-between; padding: 8px 0;">
                <span style="color: #9CA3AF; font-size: 14px;">Clouds:</span>
                <span style="font-weight: 500; font-size: 14px;">${weatherPoint.clouds_pct || 'N/A'}%</span>
              </div>
              <div style="display: flex; justify-content: space-between; padding: 8px 0;">
                <span style="color: #9CA3AF; font-size: 14px;">Visibility:</span>
                <span style="font-weight: 500; font-size: 14px;">10.00 km</span>
              </div>
            </div>
          </div>
        `, {
          maxWidth: 280,
          closeButton: true,
          className: 'weather-popup'
        })
      
      weatherLayer.addLayer(marker)
    })
    weatherLayerRef.current = weatherLayer

    // Fit map to show all points
    if (pathCoords.length > 0) {
      map.fitBounds(pathCoords)
    }
  }, [route, locationPoints, magnetometerPoints, weatherPoints])

  // Build aggregated points from ALL sessions (used by heatmap and zones)
  useEffect(() => {
    if (route !== 'heatmap' && route !== 'zones') {
      // do not clear; keep cached points so switching tabs is instant
      return
    }
    
    console.log('Loading aggregated heatmap data from all sessions...')
    // Read entire users tree once and aggregate points
    const usersRef = ref(db, 'users')
    const off = onValue(usersRef, (snap) => {
      const data = snap.val() || {}
      const pts: Array<[number, number, number]> = []
      let sessionCount = 0
      let totalPairs = 0
      
      Object.values<any>(data).forEach((user: any) => {
        const sessions = user?.sessions || {}
        Object.keys(sessions).forEach((sessionId) => {
          sessionCount++
          const s = sessions[sessionId]
          
          // Firebase stores as objects with keys, convert to arrays
          const locsObj = s?.locationData || {}
          const magsObj = s?.magnetometerData || {}
          
          // Convert Firebase object to array, preserving order if timestamp/seconds exists
          const locs: any[] = Array.isArray(locsObj) 
            ? locsObj 
            : Object.values(locsObj).sort((a: any, b: any) => (a.seconds || 0) - (b.seconds || 0))
          
          const mags: any[] = Array.isArray(magsObj)
            ? magsObj
            : Object.values(magsObj).sort((a: any, b: any) => (a.seconds || 0) - (b.seconds || 0))
          
          console.log(`Session ${sessionId}: ${locs.length} locations, ${mags.length} magnetometer readings`)
          
          // Pair by timestamp/seconds for accurate matching
          const locMap = new Map()
          locs.forEach(p => {
            if (p && typeof p.seconds !== 'undefined') {
              locMap.set(p.seconds, p)
            }
          })
          
          mags.forEach(m => {
            if (!m || typeof m.seconds === 'undefined') return
            
            // Find nearest location point within 5 seconds
            let bestLoc: any = null
            let bestDiff = Infinity
            locMap.forEach((p, locSec) => {
              const diff = Math.abs(locSec - m.seconds)
              if (diff < bestDiff && diff <= 5) {
                bestDiff = diff
                bestLoc = p
              }
            })
            
            if (bestLoc && typeof bestLoc.latitude === 'number' && typeof bestLoc.longitude === 'number') {
              const mag = Math.sqrt((m.x||0)**2 + (m.y||0)**2 + (m.z||0)**2)
              // Normalize weight roughly: 0..100 μT -> 0..1
              const weight = Math.max(0, Math.min(1, mag / 100))
              pts.push([bestLoc.latitude, bestLoc.longitude, weight])
              totalPairs++
            }
          })
        })
      })
      
      console.log(`Heatmap aggregation complete: ${sessionCount} sessions, ${totalPairs} points, ${pts.length} valid points`)
      setHeatPoints(pts)
    }, (error) => {
      console.error('Error loading heatmap data:', error)
    })
    return () => off()
  }, [route])

  // Render heatmap layer
  useEffect(() => {
    if (route !== 'heatmap') return
    if (!mapRef.current) return
    const map = mapRef.current

    // Clear session layers
    if (pathLayerRef.current) { map.removeLayer(pathLayerRef.current); pathLayerRef.current = null }
    if (markersLayerRef.current) { map.removeLayer(markersLayerRef.current); markersLayerRef.current = null }
    if (weatherLayerRef.current) { map.removeLayer(weatherLayerRef.current); weatherLayerRef.current = null }

    if (heatLayerRef.current) { map.removeLayer(heatLayerRef.current); heatLayerRef.current = null }
    if (polygonLayerRef.current) { map.removeLayer(polygonLayerRef.current); polygonLayerRef.current = null }
    
    console.log('Heatmap render:', {
      pointsCount: heatPoints.length,
      heatLayerAvailable: !!(window as any).L?.heatLayer,
      windowL: !!(window as any).L
    })

    if (heatPoints.length === 0) {
      console.log('No heat points to render')
      return
    }

    if (!(window as any).L?.heatLayer) {
      console.error('Leaflet.heat not loaded!')
      return
    }

    try {
      // Create distinct color zones like the image
      const layer = (window as any).L.heatLayer(heatPoints, {
        radius: 50, // Larger radius for zone coverage
        blur: 35, // More blur to create smooth zones
        maxZoom: 18,
        minOpacity: 0.4,
        // Distinct gradient with clear zones: green (low) -> yellow (medium) -> red (high)
        gradient: { 
          0.0: 'green',      // Low EMF
          0.4: 'green',
          0.45: '#90EE90',   // Light green transition
          0.5: 'yellow',     // Medium EMF
          0.7: '#FFA500',    // Orange transition  
          0.85: 'red',       // High EMF
          1.0: '#8B0000'     // Very high EMF (dark red)
        }
      }).addTo(map)
      
      heatLayerRef.current = layer
      console.log('Heatmap layer added successfully')
      
      if (heatPoints.length > 0) {
        const latlngs = heatPoints.map(p => [p[0], p[1]])
        map.fitBounds(latlngs as any, { padding: [20, 20] })
      }
    } catch (error) {
      console.error('Error creating heatmap:', error)
    }
  }, [route, heatPoints])

  // Render choropleth-style zones using a simple grid aggregation
  useEffect(() => {
    if (route !== 'zones') return
    if (!mapRef.current) return
    const map = mapRef.current

    // Clear other layers
    if (pathLayerRef.current) { map.removeLayer(pathLayerRef.current); pathLayerRef.current = null }
    if (markersLayerRef.current) { map.removeLayer(markersLayerRef.current); markersLayerRef.current = null }
    if (weatherLayerRef.current) { map.removeLayer(weatherLayerRef.current); weatherLayerRef.current = null }
    if (heatLayerRef.current) { map.removeLayer(heatLayerRef.current); heatLayerRef.current = null }
    if (polygonLayerRef.current) { map.removeLayer(polygonLayerRef.current); polygonLayerRef.current = null }

    // Build bins from heatPoints; ensure we have aggregated data
    const pts = heatPoints
    if (!pts || pts.length === 0) return

    // ~1km grid (approx) -> 0.01 deg (varies with latitude but OK for city scale)
    const cellDeg = 0.01
    const bins = new Map<string, { minLat: number, minLon: number, sum: number, count: number }>()
    const bounds: any[] = []
    pts.forEach(([lat, lon, weight]) => {
      const i = Math.floor(lat / cellDeg)
      const j = Math.floor(lon / cellDeg)
      const key = `${i}_${j}`
      const minLat = i * cellDeg
      const minLon = j * cellDeg
      const bin = bins.get(key) || { minLat, minLon, sum: 0, count: 0 }
      bin.sum += weight
      bin.count += 1
      bins.set(key, bin)
      bounds.push([lat, lon])
    })

    const layer = (window as any).L.layerGroup()
    bins.forEach((bin) => {
      const avg = bin.sum / Math.max(1, bin.count)
      let color = 'green'
      if (avg > 0.7) color = 'red'
      else if (avg > 0.5) color = '#FFA500'
      else if (avg > 0.35) color = 'yellow'

      const rect = (window as any).L.rectangle(
        [
          [bin.minLat, bin.minLon],
          [bin.minLat + cellDeg, bin.minLon + cellDeg]
        ],
        {
          color,
          weight: 1,
          fillColor: color,
          fillOpacity: 0.35
        }
      ).bindPopup(`Avg EMF weight: ${avg.toFixed(2)}\nSamples: ${bin.count}`)
      layer.addLayer(rect)
    })
    layer.addTo(map)
    polygonLayerRef.current = layer

    map.fitBounds(bounds as any, { padding: [20, 20] })
  }, [route, heatPoints])

  return (
    <div className="dashboard-container">
      <style>{`
        * {
          margin: 0;
          padding: 0;
          box-sizing: border-box;
        }
        
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
          background: #0B1426;
          color: #fff;
          overflow: hidden;
        }
        
        .dashboard-container {
          display: flex;
          height: 100vh;
          background: #0B1426;
        }
        
        .sidebar {
          width: 300px;
          background: linear-gradient(180deg, #1A2332 0%, #0F1B2E 100%);
          border-right: 1px solid #2A3441;
          display: flex;
          flex-direction: column;
          overflow: hidden;
        }
        
        .header {
          padding: 24px 20px;
          border-bottom: 1px solid #2A3441;
        }
        
        .logo {
          display: flex;
          align-items: center;
          gap: 12px;
          margin-bottom: 8px;
        }
        
        .logo-icon {
          width: 32px;
          height: 32px;
          background: linear-gradient(45deg, #6366F1, #8B5CF6);
          border-radius: 8px;
          display: flex;
          align-items: center;
          justify-content: center;
          font-size: 18px;
        }
        
        .logo-text {
          font-size: 18px;
          font-weight: 600;
          color: #fff;
        }
        
        .version {
          background: #374151;
          padding: 2px 8px;
          border-radius: 4px;
          font-size: 11px;
          color: #9CA3AF;
        }
        
        .subtitle {
          color: #9CA3AF;
          font-size: 12px;
          margin-top: 4px;
        }
        
        .sidebar-content {
          flex: 1;
          overflow-y: auto;
          padding: 0 20px 20px;
        }
        
        .section {
          margin-bottom: 32px;
        }
        
        .section-title {
          font-size: 12px;
          font-weight: 500;
          color: #9CA3AF;
          text-transform: uppercase;
          letter-spacing: 0.05em;
          margin-bottom: 16px;
        }
        
        .filter-item {
          display: flex;
          align-items: center;
          gap: 12px;
          padding: 12px 16px;
          margin-bottom: 8px;
          border-radius: 8px;
          cursor: pointer;
          transition: all 0.2s ease;
          border: 1px solid transparent;
        }
        
        .filter-item:hover {
          background: rgba(99, 102, 241, 0.1);
          border-color: rgba(99, 102, 241, 0.3);
        }
        
        .filter-item.active {
          background: rgba(99, 102, 241, 0.15);
          border-color: #6366F1;
        }
        
        .filter-icon {
          width: 20px;
          height: 20px;
          display: flex;
          align-items: center;
          justify-content: center;
          font-size: 14px;
        }
        
        .session-item {
          padding: 16px;
          margin-bottom: 8px;
          border-radius: 8px;
          background: rgba(255, 255, 255, 0.05);
          border: 1px solid rgba(255, 255, 255, 0.1);
          cursor: pointer;
          transition: all 0.2s ease;
        }
        
        .session-item:hover {
          background: rgba(99, 102, 241, 0.1);
          border-color: rgba(99, 102, 241, 0.3);
        }
        
        .session-item.selected {
          background: rgba(99, 102, 241, 0.15);
          border-color: #6366F1;
        }
        
        .session-date {
          font-size: 14px;
          font-weight: 500;
          color: #fff;
          margin-bottom: 4px;
        }
        
        .session-meta {
          font-size: 11px;
          color: #9CA3AF;
          display: flex;
          align-items: center;
          gap: 8px;
        }
        
        .status-dot {
          width: 6px;
          height: 6px;
          border-radius: 50%;
          background: #10B981;
        }
        
        .new-badge {
          background: #10B981;
          color: #fff;
          padding: 2px 6px;
          border-radius: 4px;
          font-size: 9px;
          font-weight: 500;
          text-transform: uppercase;
        }
        
        .live-data-section {
          margin-top: auto;
          padding-top: 20px;
          border-top: 1px solid #2A3441;
        }
        
        .live-indicator {
          display: flex;
          align-items: center;
          gap: 8px;
          margin-bottom: 12px;
        }
        
        .live-dot {
          width: 8px;
          height: 8px;
          border-radius: 50%;
          background: #10B981;
          animation: pulse 2s infinite;
        }
        
        @keyframes pulse {
          0%, 100% { opacity: 1; }
          50% { opacity: 0.5; }
        }
        
        .metric-card {
          background: rgba(255, 255, 255, 0.05);
          border: 1px solid rgba(255, 255, 255, 0.1);
          border-radius: 8px;
          padding: 16px;
          text-align: center;
        }
        
        .metric-icon {
          font-size: 24px;
          margin-bottom: 8px;
        }
        
        .metric-value {
          font-size: 24px;
          font-weight: 700;
          color: #6366F1;
          margin-bottom: 4px;
        }
        
        .metric-label {
          font-size: 11px;
          color: #9CA3AF;
          text-transform: uppercase;
          letter-spacing: 0.05em;
        }
        
        .map-container {
          flex: 1;
          position: relative;
        }
        
        .sessions-scroll-container {
          max-height: 300px;
          overflow-y: auto;
          padding-right: 4px;
        }
        
        .sessions-scroll-container::-webkit-scrollbar {
          width: 4px;
        }
        
        .sessions-scroll-container::-webkit-scrollbar-track {
          background: rgba(255, 255, 255, 0.1);
          border-radius: 2px;
        }
        
        .sessions-scroll-container::-webkit-scrollbar-thumb {
          background: rgba(99, 102, 241, 0.6);
          border-radius: 2px;
        }
        
        .sessions-scroll-container::-webkit-scrollbar-thumb:hover {
          background: rgba(99, 102, 241, 0.8);
        }
        
        .weather-popup .leaflet-popup-content-wrapper {
          background: transparent !important;
          box-shadow: none !important;
          padding: 0 !important;
        }
        
        .weather-popup .leaflet-popup-content {
          margin: 0 !important;
        }
        
        .weather-popup .leaflet-popup-close-button {
          color: white !important;
          font-size: 18px !important;
          padding: 8px !important;
        }
        
        .map-view {
          width: 100%;
          height: 100%;
        }
        
        .emf-intensity-zone {
          fill-opacity: 0.03 !important;
          stroke-opacity: 0.2 !important;
        }
      `}</style>
      
      <div className="sidebar">
        <div className="header">
          <div className="logo">
            <div className="logo-icon">📡</div>
            <div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span className="logo-text">EMF Live Dashboard</span>
                <span className="version">v2.0</span>
              </div>
              <div className="subtitle">Real-time monitoring active</div>
            </div>
          </div>
        </div>
        
        <div className="sidebar-content">
          <div className="section">
            <div className="section-title">Display Filters</div>
            <div 
              className={`filter-item ${route === 'live' ? 'active' : ''}`}
              onClick={() => window.location.hash = '#/live'}
            >
              <div className="filter-icon">📊</div>
              <span>Lux Measurements</span>
            </div>
            <div 
              className={`filter-item ${route === 'heatmap' ? 'active' : ''}`}
              onClick={() => window.location.hash = '#/heatmap'}
            >
              <div className="filter-icon">🔥</div>
              <span>Heatmap (All Sensors)</span>
            </div>
            <div 
              className={`filter-item ${route === 'zones' ? 'active' : ''}`}
              onClick={() => window.location.hash = '#/zones'}
            >
              <div className="filter-icon">🟪</div>
              <span>Zones (All Sessions)</span>
            </div>
          </div>
          
          <div className="section">
            <div className="section-title">
              Recording Sessions 
              <span style={{ 
                background: '#6366F1', 
                color: '#fff', 
                padding: '2px 6px', 
                borderRadius: '4px', 
                fontSize: '10px',
                marginLeft: '8px'
              }}>
                {sessions.length}
              </span>
            </div>
            <div className="sessions-scroll-container">
              {sessions.map((session, index) => (
              <div 
                key={session.id}
                className={`session-item ${selectedSession === session.id ? 'selected' : ''}`}
                onClick={() => setSelectedSession(session.id)}
              >
                <div className="session-date">
                  {new Date(session.timestamp).toLocaleDateString('en-GB', {
                    day: '2-digit',
                    month: '2-digit',
                    year: 'numeric',
                    hour: '2-digit',
                    minute: '2-digit'
                  })}
                  {index < 2 && <span className="new-badge" style={{ marginLeft: '8px' }}>New</span>}
                </div>
                <div className="session-meta">
                  <div className="status-dot"></div>
                  <span>Completed</span>
                  <span>•</span>
                  <span>{session.status === 'completed' ? 'Dublin City' : `Location ${String.fromCharCode(65 + index)}`}</span>
                </div>
              </div>
              ))}
            </div>
          </div>
          
          <div className="live-data-section">
            <div className="live-indicator">
              <div className="live-dot"></div>
              <span className="section-title" style={{ margin: 0 }}>Live Data</span>
              <span style={{ 
                background: '#10B981', 
                color: '#fff', 
                padding: '2px 6px', 
                borderRadius: '4px', 
                fontSize: '9px',
                marginLeft: 'auto'
              }}>
                Active
              </span>
            </div>
            
            <div className="metric-card">
              <div className="metric-icon">📍</div>
              <div className="metric-value">{locationPoints.length.toLocaleString()}</div>
              <div className="metric-label">Location Points</div>
            </div>
          </div>
        </div>
      </div>
      
      <div className="map-container">
        <div ref={mapDivRef} className="map-view" />
      </div>
    </div>
  )
}