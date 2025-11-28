import React, { useEffect, useState } from 'react'
import { ref, onValue, onChildAdded } from 'firebase/database'
import { db } from '../firebase'

interface Session {
  id: string
  timestamp: string
  status: string
}

interface HeartRateReading {
  id: string
  seconds: number
  bpm: number
  timestamp: string
}

export const HeartRateDebugger: React.FC = () => {
  const [sessions, setSessions] = useState<Session[]>([])
  const [selectedSession, setSelectedSession] = useState<string | null>(null)
  const [heartRateData, setHeartRateData] = useState<HeartRateReading[]>([])
  const [isListening, setIsListening] = useState(false)

  // Load sessions
  useEffect(() => {
    const sessionsRef = ref(db, 'users')
    const unsubscribe = onValue(sessionsRef, (snapshot) => {
      const data = snapshot.val()
      if (data) {
        const sessionList: Session[] = []
        Object.keys(data).forEach(userId => {
          const userSessions = data[userId]?.sessions
          if (userSessions) {
            Object.keys(userSessions).forEach(sessionId => {
              sessionList.push({
                id: sessionId,
                timestamp: userSessions[sessionId].timestamp,
                status: userSessions[sessionId].status
              })
            })
          }
        })
        setSessions(sessionList.sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime()))
      }
    })
    return () => unsubscribe()
  }, [])

  // Listen to heart rate data for selected session
  useEffect(() => {
    if (!selectedSession) {
      setHeartRateData([])
      setIsListening(false)
      return
    }

    setHeartRateData([])
    setIsListening(true)

    const sessionsRef = ref(db, 'users')
    const unsubscribe = onValue(sessionsRef, (snapshot) => {
      const data = snapshot.val()
      if (data) {
        Object.keys(data).forEach(userId => {
          const userSessions = data[userId]?.sessions
          if (userSessions && userSessions[selectedSession]) {
            const heartRateRef = ref(db, `users/${userId}/sessions/${selectedSession}/heartRateData`)
            onChildAdded(heartRateRef, (snapshot) => {
              const reading = snapshot.val()
              setHeartRateData(prev => [...prev, {
                id: snapshot.key!,
                ...reading
              }].sort((a, b) => a.seconds - b.seconds))
            })
          }
        })
      }
    })

    return () => {
      unsubscribe()
      setIsListening(false)
    }
  }, [selectedSession])

  const latestReading = heartRateData[heartRateData.length - 1]

  return (
    <div style={{
      background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
      color: 'white',
      padding: '24px',
      borderRadius: '16px',
      margin: '16px 0',
      boxShadow: '0 8px 32px rgba(0,0,0,0.3)'
    }}>
      <div style={{
        display: 'flex',
        alignItems: 'center',
        gap: '16px',
        marginBottom: '24px'
      }}>
        <div style={{ fontSize: '32px' }}>💓</div>
        <div>
          <h2 style={{ margin: 0, fontSize: '24px', fontWeight: 'bold' }}>
            Heart Rate Monitor
          </h2>
          <p style={{ margin: '4px 0 0', opacity: 0.8, fontSize: '14px' }}>
            Real-time heart rate data from Google Fit
          </p>
        </div>
        {isListening && (
          <div style={{
            marginLeft: 'auto',
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            background: 'rgba(255,255,255,0.2)',
            padding: '8px 12px',
            borderRadius: '20px',
            fontSize: '12px',
            fontWeight: 'bold'
          }}>
            <div style={{
              width: '8px',
              height: '8px',
              background: '#10B981',
              borderRadius: '50%',
              animation: 'pulse 2s infinite'
            }}></div>
            LIVE
          </div>
        )}
      </div>

      <div style={{
        display: 'grid',
        gridTemplateColumns: '1fr 1fr',
        gap: '16px',
        marginBottom: '20px'
      }}>
        <div>
          <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', opacity: 0.8 }}>
            Select Session
          </label>
          <select
            value={selectedSession || ''}
            onChange={(e) => setSelectedSession(e.target.value || null)}
            style={{
              width: '100%',
              padding: '12px',
              borderRadius: '8px',
              border: 'none',
              background: 'rgba(255,255,255,0.15)',
              color: 'white',
              fontSize: '14px'
            }}
          >
            <option value="">Choose a session...</option>
            {sessions.map(session => (
              <option key={session.id} value={session.id} style={{ color: 'black' }}>
                {new Date(session.timestamp).toLocaleDateString()} - {session.status}
              </option>
            ))}
          </select>
        </div>
        
        <div>
          <div style={{ fontSize: '14px', opacity: 0.8, marginBottom: '4px' }}>
            Latest BPM
          </div>
          <div style={{
            fontSize: '32px',
            fontWeight: 'bold',
            background: 'rgba(255,255,255,0.15)',
            padding: '12px',
            borderRadius: '8px',
            textAlign: 'center'
          }}>
            {latestReading ? `${latestReading.bpm}` : '--'}
          </div>
        </div>
      </div>

      {selectedSession && (
        <div style={{
          background: 'rgba(255,255,255,0.1)',
          borderRadius: '12px',
          padding: '16px'
        }}>
          <div style={{
            display: 'flex',
            justifyContent: 'space-between',
            marginBottom: '12px'
          }}>
            <span style={{ fontWeight: 'bold' }}>Heart Rate Readings</span>
            <span style={{ fontSize: '12px', opacity: 0.8 }}>
              {heartRateData.length} readings
            </span>
          </div>
          
          <div style={{
            maxHeight: '200px',
            overflowY: 'auto',
            display: 'grid',
            gap: '8px'
          }}>
            {heartRateData.length === 0 ? (
              <div style={{ textAlign: 'center', opacity: 0.6, padding: '20px' }}>
                {isListening ? 'Waiting for heart rate data...' : 'No heart rate data found'}
              </div>
            ) : (
              heartRateData.slice(-10).reverse().map((reading, index) => (
                <div
                  key={reading.id}
                  style={{
                    display: 'flex',
                    justifyContent: 'space-between',
                    alignItems: 'center',
                    background: index === 0 ? 'rgba(16, 185, 129, 0.2)' : 'rgba(255,255,255,0.05)',
                    padding: '8px 12px',
                    borderRadius: '6px',
                    fontSize: '14px'
                  }}
                >
                  <span>{reading.bpm} BPM</span>
                  <span style={{ opacity: 0.7, fontSize: '12px' }}>
                    {reading.seconds.toFixed(0)}s
                  </span>
                  <span style={{ opacity: 0.7, fontSize: '11px' }}>
                    {new Date(reading.timestamp).toLocaleTimeString()}
                  </span>
                </div>
              ))
            )}
          </div>
        </div>
      )}

      <style>{`
        @keyframes pulse {
          0% { opacity: 1; }
          50% { opacity: 0.5; }
          100% { opacity: 1; }
        }
      `}</style>
    </div>
  )
}
