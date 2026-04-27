# FiftyFood Port Configuration & Quick Start Guide

## 🚀 Quick Start - Run Both Applications

### Option 1: PowerShell Script (Easiest)
```powershell
cd C:\Users\ismai\FiftyFood
.\run_all.ps1
```
This opens 3 new PowerShell windows automatically:
- Backend ✅
- Admin ✅  
- Restaurant ✅

### Option 2: Manual - 3 Separate Terminals
```bash
# Terminal 1 - Backend
cd C:\Users\ismai\FiftyFood\backend
npm run dev

# Terminal 2 - Admin
cd C:\Users\ismai\FiftyFood\frontend-web\admin
npm run dev

# Terminal 3 - Restaurant
cd C:\Users\ismai\FiftyFood\frontend-web\restaurant
npm run dev
```

### Option 3: npm scripts from root
```bash
# Terminal 1
npm run dev:backend

# Terminal 2
npm run dev:admin

# Terminal 3
npm run dev:restaurant
```

---

## 📋 Port Configuration Table

| Application | Port | URL | File |
|------------|------|-----|------|
| **Backend (NestJS)** | 3000 | http://localhost:3000 | `backend/src/main.ts` |
| **Admin Dashboard** | 5174 | http://localhost:5174 | `frontend-web/admin/vite.config.ts` |
| **Restaurant Portal** | 5175 | http://localhost:5175 | `frontend-web/restaurant/vite.config.ts` |

---

## 🔍 Where Ports Are Configured

### Backend Port
**File**: `backend/src/main.ts`
```typescript
await app.listen(3000, '0.0.0.0');
```

### Admin Port
**File**: `frontend-web/admin/vite.config.ts`
```typescript
server: {
  port: 5174,
  strictPort: true,
}
```

### Restaurant Port
**File**: `frontend-web/restaurant/vite.config.ts`
```typescript
server: {
  port: 5175,
  strictPort: true,
}
```

---

## 🌐 Access the Applications

Once all are running, open your browser:

1. **Admin Panel** → http://localhost:5174
   - Login with admin credentials
   - Manage restaurants, users, and system settings

2. **Restaurant Portal** → http://localhost:5175
   - Login with restaurant credentials
   - Manage offers, orders, and dashboard

3. **API Documentation** (if available) → http://localhost:3000

---

## ⚙️ Network Access

### Local Machine
- Use `localhost:PORT` or `127.0.0.1:PORT`

### Same Network (over WiFi)
- Use your machine IP: `http://192.168.61.154:PORT`
- Example: `http://192.168.61.154:5174` (Admin)

---

## 🛑 Stopping Applications

**Press `Ctrl + C`** in each terminal to stop the server gracefully.

Or close all PowerShell windows if using `run_all.ps1`.

---

## 🐛 Troubleshooting Ports

### Check which process is using a port:
```powershell
# Windows - Check port 5174
netstat -ano | findstr :5174

# Windows - Check port 5175  
netstat -ano | findstr :3000
```

### Kill process on a port:
```powershell
# Get the PID from netstat, then kill it
taskkill /PID <PID> /F

# Example: Kill process on 5174
netstat -ano | findstr :5174
taskkill /PID 12345 /F
```

### Change a port (if needed):
Edit the appropriate `vite.config.ts` or `src/main.ts` file and change the port number, then restart the dev server.

---

## 📊 Architecture

```
┌─────────────────────────────────────┐
│    FiftyFood - Dual Dashboard       │
├─────────────────────────────────────┤
│ Admin (5174)  │  Restaurant (5175)  │
│ React + Vite  │  React + Vite       │
└────────┬──────┴────────┬────────────┘
         │               │
         └───────┬───────┘
                 │
                 ↓
         ┌──────────────────┐
         │ Backend (3000)   │
         │ NestJS + Prisma  │
         │ PostgreSQL DB    │
         └──────────────────┘
```

---

## 📝 Environment Setup Checklist

- [ ] Node.js installed (`node -v`)
- [ ] npm installed (`npm -v`)
- [ ] Backend dependencies installed (`cd backend && npm install`)
- [ ] Admin dependencies installed (`cd frontend-web/admin && npm install`)
- [ ] Restaurant dependencies installed (`cd frontend-web/restaurant && npm install`)
- [ ] Backend database running (PostgreSQL)
- [ ] Backend environment variables configured (`.env`)

---

**Last Updated**: April 19, 2026
**Version**: 1.0.0
