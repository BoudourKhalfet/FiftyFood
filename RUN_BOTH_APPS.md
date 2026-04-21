# Running Admin & Restaurant Frontends Simultaneously

This guide explains how to run both the **Admin Dashboard** and **Restaurant Portal** at the same time.

## Port Configuration

- **Backend (NestJS)**: `http://localhost:3000`
- **Admin Frontend**: `http://localhost:5174`
- **Restaurant Frontend**: `http://localhost:5175`

## Prerequisites

Make sure you have:
- Node.js installed
- All dependencies installed for both frontend projects
- Backend running on port 3000

## Running Both Simultaneously

### Option 1: Using Multiple Terminals (Recommended for Development)

**Terminal 1 - Backend:**
```bash
cd C:\Users\ismai\FiftyFood\backend
npm run dev
# Or: npm start run:dev
```

**Terminal 2 - Admin Frontend:**
```bash
cd C:\Users\ismai\FiftyFood\frontend-web\admin
npm run dev
```

**Terminal 3 - Restaurant Frontend:**
```bash
cd C:\Users\ismai\FiftyFood\frontend-web\restaurant
npm run dev
```

### Option 2: Using PowerShell (Run All at Once)

```powershell
# Open 3 separate PowerShell windows and run each command in parallel

# Window 1:
cd C:\Users\ismai\FiftyFood\backend; npm run dev

# Window 2:
cd C:\Users\ismai\FiftyFood\frontend-web\admin; npm run dev

# Window 3:
cd C:\Users\ismai\FiftyFood\frontend-web\restaurant; npm run dev
```

## Accessing the Applications

Once all three processes are running:

| Application | URL | Purpose |
|-------------|-----|---------|
| **Admin Dashboard** | http://localhost:5174 | Manage system, view all restaurants |
| **Restaurant Portal** | http://localhost:5175 | Manage restaurant operations |
| **Backend API** | http://localhost:3000 | API endpoints |

## Testing Different Roles

1. **Login to Admin** (http://localhost:5174):
   - Use admin credentials to manage restaurants and users

2. **Login to Restaurant** (http://localhost:5175):
   - Use restaurant credentials to manage offers and orders

## Port Conflicts

If a port is already in use, you'll see an error. To fix this:

**For Admin (Port 5174):**
- Edit `frontend-web/admin/vite.config.ts`
- Change `port: 5174` to a different port (e.g., `5176`)

**For Restaurant (Port 5175):**
- Edit `frontend-web/restaurant/vite.config.ts`
- Change `port: 5175` to a different port (e.g., `5177`)

## Current Configuration

### Admin (`frontend-web/admin/vite.config.ts`)
```typescript
server: {
  port: 5174,
  strictPort: true,
}
```

### Restaurant (`frontend-web/restaurant/vite.config.ts`)
```typescript
server: {
  port: 5175,
  strictPort: true,
}
```

## Stopping the Applications

- **Press `Ctrl + C`** in each terminal to stop the dev server
- Or **close all PowerShell windows**

## Troubleshooting

### "Port already in use" Error
```bash
# Windows - Kill process on port 5174
netstat -ano | findstr :5174
taskkill /PID <PID> /F

# Windows - Kill process on port 5175
netstat -ano | findstr :5175
taskkill /PID <PID> /F

# Windows - Kill process on port 3000
netstat -ano | findstr :3000
taskkill /PID <PID> /F
```

### App Not Loading
1. Verify backend is running (check port 3000)
2. Check browser console for errors (F12)
3. Verify environment variables (.env file)
4. Clear browser cache (Ctrl + Shift + Delete)

## Architecture Overview

```
┌─────────────────────────────────────────────────┐
│         FiftyFood Application Stack            │
├─────────────────────────────────────────────────┤
│ Admin Dashboard     │ Restaurant Portal         │
│ (React + Vite)      │ (React + Vite)           │
│ Port: 5174          │ Port: 5175               │
└──────────┬──────────┴────────────┬──────────────┘
           │                       │
           └───────────┬───────────┘
                       │
                       ↓
         ┌─────────────────────────┐
         │  Backend (NestJS)       │
         │  Port: 3000             │
         │  - Authentication       │
         │  - Restaurant API       │
         │  - Admin API            │
         │  - Database (Prisma)    │
         └─────────────────────────┘
```

## Environment Variables

Both frontends use `http://192.168.61.154:3000` for API calls. 

**File: `.env` (if needed)**
```
VITE_API_URL=http://192.168.61.154:3000
```

Check:
- `frontend-web/admin/.env` (if exists)
- `frontend-web/restaurant/.env` (if exists)

## Next Steps

- Test login flows for both applications
- Verify data synchronization between portals
- Test responsive design on different screen sizes
- Deploy to production when ready

---

**Last Updated**: April 19, 2026
