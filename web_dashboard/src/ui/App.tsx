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
        html: `<div style="font-size:22px; line-height:22px">🌤️</div>`,
        className: 'weather-icon',
        iconSize: [24, 24],
        iconAnchor: [12, 12]
      })
      
      const marker = (window as any).L.marker([weatherPoint.lat, weatherPoint.lon], { icon: weatherIcon })
        .bindPopup(`
          <b>Weather Data</b><br>
          Temp: ${weatherPoint.temp?.toFixed(1) || 'N/A'}°C<br>
          Humidity: ${weatherPoint.humidity || 'N/A'}%<br>
          Pressure: ${weatherPoint.pressure_hpa || 'N/A'} hPa<br>
          Wind: ${weatherPoint.wind_ms?.toFixed(1) || 'N/A'} m/s<br>
          Rain: ${weatherPoint.rain_1h_mm || '0'} mm<br>
          Clouds: ${weatherPoint.clouds_pct || 'N/A'}%<br>
          <small>${new Date(weatherPoint.ts).toLocaleString()}</small>
        `)
      
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
    <>
      <style>{`
        .emf-intensity-zone {
          fill-opacity: 0.03 !important;
          stroke-opacity: 0.2 !important;
        }
      `}</style>
      <div style={{ display: 'grid', gridTemplateColumns: '320px 1fr', height: '100vh', overflow: 'hidden', width: '100vw' }}>
      <div style={{ padding: 12, borderRight: '1px solid #eee', overflowY: 'auto', height: '100vh' }}>
        <h3 style={{ marginTop: 0 }}>EMF Live Dashboard</h3>
        <div style={{ display: 'flex', gap: 8, marginBottom: 12 }}>
          <a href="#/live" style={{ textDecoration: route==='live'?'underline':'none' }}>Live</a>
          <a href="#/heatmap" style={{ textDecoration: route==='heatmap'?'underline':'none' }}>Heatmap (All Sessions)</a>
          <a href="#/zones" style={{ textDecoration: route==='zones'?'underline':'none' }}>Zones (All Sessions)</a>
        </div>
        
        <div style={{ marginBottom: 16 }}>
          <h4>Sessions ({sessions.length})</h4>
          <div style={{ maxHeight: '200px', overflowY: 'auto' }}>
            {sessions.map(session => (
              <div 
                key={session.id}
                style={{ 
                  padding: '8px', 
                  margin: '4px 0', 
                  border: selectedSession === session.id ? '2px solid #007bff' : '1px solid #ddd',
                  borderRadius: '4px',
                  cursor: 'pointer',
                  backgroundColor: selectedSession === session.id ? '#f0f8ff' : 'white'
                }}
                onClick={() => setSelectedSession(session.id)}
              >
                <div style={{ fontSize: '12px', fontWeight: 'bold' }}>
                  {new Date(session.timestamp).toLocaleString()}
                </div>
                <div style={{ fontSize: '11px', color: '#666' }}>
                  Status: {session.status} | Samples: {session.totalSamples || 0}
                </div>
              </div>
            ))}
          </div>
        </div>

        {route==='live' && selectedSession && (
          <div>
            <h4>Live Data</h4>
            <p>Location points: {locationPoints.length}</p>
            <p>EMF readings: {magnetometerPoints.length} total, {emfMappedCount} mapped</p>
            <p>Weather readings: {weatherPoints.length}</p>
            {magnetometerPoints.length > 0 && (
              <p style={{ fontSize: '11px', color: '#666', fontStyle: 'italic' }}>
                {Math.round((emfMappedCount / magnetometerPoints.length) * 100)}% of EMF readings mapped to route
              </p>
            )}
            
            {weatherPoints.length > 0 && (
              <div style={{ marginTop: 12, padding: 8, backgroundColor: '#f8f9fa', borderRadius: 4 }}>
                <h5 style={{ margin: '0 0 8px 0', fontSize: '14px' }}>Latest Weather</h5>
                {(() => {
                  const latest = weatherPoints[weatherPoints.length - 1]
                  return (
                    <div style={{ fontSize: '12px' }}>
                      <div>🌡️ {latest.temp?.toFixed(1) || 'N/A'}°C</div>
                      <div>💧 {latest.humidity || 'N/A'}% humidity</div>
                      <div>🌬️ {latest.wind_ms?.toFixed(1) || 'N/A'} m/s wind</div>
                      <div>☁️ {latest.clouds_pct || 'N/A'}% clouds</div>
                      <div>🌧️ {latest.rain_1h_mm || '0'} mm rain</div>
                    </div>
                  )
                })()}
              </div>
            )}
            
            <div style={{ fontSize: '12px', color: '#666', marginTop: 12 }}>
              <div><strong>EMF Legend:</strong></div>
              <div>🟢 Low EMF (&lt;30 μT)</div>
              <div>🟠 Medium EMF (30-50 μT)</div>
              <div>🔴 High EMF (&gt;50 μT)</div>
              <div style={{ marginTop: 8 }}><strong>Map Markers:</strong></div>
              <div>🌤️ Weather data points</div>
            </div>
          </div>
        )}

        {route==='heatmap' && (
          <div>
            <h4>Heatmap (All Sessions)</h4>
            <p>Points: {heatPoints.length}</p>
            <div style={{ fontSize: '12px', color: '#666' }}>
              <div><strong>Gradient:</strong> Green → Yellow → Red (higher EMF)</div>
              <div>Radius 24px, blur 18px, normalized weight = magnitude/100</div>
            </div>
          </div>
        )}

        {route==='zones' && (
          <div>
            <h4>Zones (All Sessions)</h4>
            <p>Cells derived from ~1km grid, colored by average EMF weight.</p>
            <div style={{ fontSize: '12px', color: '#666' }}>
              <div>Green: low, Yellow: medium, Orange: elevated, Red: high</div>
            </div>
          </div>
        )}
      </div>
      <div ref={mapDivRef} style={{ height: '100vh', width: '100%', overflow: 'hidden', position: 'relative' }} />
    </div>
    </>
  )
}