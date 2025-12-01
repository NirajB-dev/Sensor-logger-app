# EMF Live Dashboard

A real-time web dashboard for visualizing EMF sensor data from the Flutter mobile app.

## Features

- Live session monitoring with real-time data updates
- Interactive map with EMF intensity zones
- Weather data integration with heart rate monitoring
- Heatmap and zone visualization modes
- Session history and filtering

## Local Development

1. Copy `env.example` to `.env`:
   ```bash
   cp env.example .env
   ```

2. Fill in your Firebase configuration in `.env`

3. Install dependencies:
   ```bash
   npm install
   ```

4. Run development server:
   ```bash
   npm run dev
   ```

5. Open http://localhost:5173 in your browser

## Vercel Deployment

### Method 1: Vercel CLI (Recommended)

1. Install Vercel CLI:
   ```bash
   npm i -g vercel
   ```

2. Login to Vercel:
   ```bash
   vercel login
   ```

3. Deploy from the web_dashboard directory:
   ```bash
   cd web_dashboard
   vercel
   ```

4. Follow the prompts:
   - Set up and deploy? **Y**
   - Which scope? Select your account
   - Link to existing project? **N**
   - Project name: `emf-live-dashboard` (or your preferred name)
   - In which directory is your code located? **./web_dashboard**

5. Set environment variables in Vercel Dashboard:
   - Go to https://vercel.com/dashboard
   - Select your project → Settings → Environment Variables
   - Add all Firebase config variables from `.env.production`

### Method 2: GitHub Integration

1. Push your code to GitHub
2. Go to https://vercel.com/dashboard
3. Click "New Project"
4. Import your GitHub repository
5. Set build settings:
   - **Root Directory**: `web_dashboard`
   - **Build Command**: `npm run build`
   - **Output Directory**: `dist`
6. Add environment variables (same as Method 1)
7. Deploy

### Environment Variables Required

Copy these from your Firebase Console → Project Settings → Web App:

```
VITE_FIREBASE_API_KEY
VITE_FIREBASE_AUTH_DOMAIN
VITE_FIREBASE_DB_URL
VITE_FIREBASE_PROJECT_ID
VITE_FIREBASE_STORAGE_BUCKET
VITE_FIREBASE_SENDER_ID
VITE_FIREBASE_APP_ID
```

### Firebase Security Rules

Ensure your Firebase Realtime Database rules allow web access:

```json
{
  "rules": {
    ".read": "auth == null",
    ".write": "auth == null"
  }
}
```

## Live Demo

Once deployed, your dashboard will be available at:
`https://your-project-name.vercel.app`
