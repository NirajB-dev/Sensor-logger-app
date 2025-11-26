import { initializeApp } from 'firebase/app'
import { getDatabase } from 'firebase/database'

// Provide these via environment variables when running/building
// Vite exposes env starting with VITE_
const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  databaseURL: import.meta.env.VITE_FIREBASE_DB_URL,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: import.meta.env.VITE_FIREBASE_SENDER_ID,
  appId: import.meta.env.VITE_FIREBASE_APP_ID,
}

// Check if config is complete
const missingKeys = Object.entries(firebaseConfig)
  .filter(([key, value]) => !value || value.includes('your_'))
  .map(([key]) => key)

if (missingKeys.length > 0) {
  console.error('Missing Firebase config:', missingKeys)
  console.error('Create .env file with values from Firebase Console → Project Settings → Web App')
}

export const app = initializeApp(firebaseConfig)
export const db = getDatabase(app)
