# EMF Live Web Dashboard (React + MapLibre)

## Run locally

1. Fill a `.env` file in this folder with your Firebase web config:
```
VITE_FIREBASE_API_KEY=...
VITE_FIREBASE_AUTH_DOMAIN=...
VITE_FIREBASE_DB_URL=...
VITE_FIREBASE_PROJECT_ID=...
VITE_FIREBASE_STORAGE_BUCKET=...
VITE_FIREBASE_SENDER_ID=...
VITE_FIREBASE_APP_ID=...
```

2. Install deps and start dev server:
```
npm install
npm run dev
```

The app opens at http://localhost:5173

## Notes
- Map uses MapLibre with a free demo style (replace with your own style URL for production).
- Next steps: wire Firebase listeners to draw live paths/points from `users/{uid}/sessions/{sessionId}`.
