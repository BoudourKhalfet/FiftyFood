# Restaurant Dashboard Setup Guide

## Overview

Le dashboard restaurant affiche les statistiques et performances du restaurant connecté à FiftyFood. Il communique avec le backend via des endpoints JWT-protégés.

## Architecture

### Backend (NestJS)
**Endpoint:** `GET /restaurant/onboarding/stats`

Retourne les statistiques du restaurant :
```json
{
  "totalSales": 2848,          // Total des ventes (€)
  "totalOrders": 150,          // Nombre total de commandes
  "totalMealsSaved": 156,      // Nombre total de repas sauvés
  "avgRating": 4.7,            // Note moyenne
  "activeOffers": 3,           // Offres actives

  "revenue7d": 2847,           // Revenue des 7 derniers jours (€)
  "orders7d": 163,             // Commandes des 7 derniers jours
  "mealsSaved7d": 196,         // Repas sauvés (7 derniers jours)
  "revenueChangePercent": 12.4, // % de changement vs semaine précédente
  "ordersChangePercent": 8.1   // % de changement vs semaine précédente
}
```

### Frontend (React + Vite)
- **Components:**
  - `Dashboard.tsx` - Composant principal affichant les stats
  - `DashboardPage.tsx` - Wrapper page
- **API:**
  - `restaurantApi.ts` - Service pour les appels API
- **Auth:**
  - Utilise JWT token (access_token ou onboarding_token)
  - Stocké dans localStorage
  - Inclus dans l'en-tête Authorization

## Installation & Setup

### 1. Configuration du Backend

Le backend retourne maintenant des stats enrichies. Assurez-vous que le service est à jour :

```bash
cd backend
npm install
npm run start:dev
```

### 2. Configuration du Frontend Restaurant

```bash
cd frontend-web/restaurant
npm install
```

### 3. Variables d'environnement

Créez/vérifiez le fichier `.env` :

```env
VITE_API_URL=http://192.168.194.154:3000
```

**Adaptation selon votre réseau:**
- Local: `http://localhost:3000`
- Réseau interne: `http://192.168.194.154:3000` (votre IP Wi-Fi)
- Production: `https://your-domain.com`

### 4. Démarrage du Frontend

```bash
npm run dev
```

L'app sera disponible à : `http://localhost:5173`

## Features

### 📊 Dashboard Stats

**Top Stats (visibles partout)**
- Total Sales (€)
- Meals Saved (quantité)
- Average Rating (⭐)
- Active Offers (nombre)

**Performance (7 jours)**
- Revenue (€) avec % changement
- Orders (nombre) avec % changement
- Meals Saved (quantité) avec % changement
- Rating trend

**Quick Stats**
- Total Orders
- Average Order Value
- Active Offers Count
- Current Rating
- This Week Orders
- This Week Revenue

### 🔐 Authentification

1. **Login Page**
   - Récupère email/password
   - Appelle `/auth/login`
   - Stocke le token JWT
   - Redirige vers dashboard

2. **Protected Access**
   - Token inclus dans tous les requests
   - Rejet 401 = redirection vers login
   - Logout efface le token

## API Calls

### Get Restaurant Stats

```typescript
GET /restaurant/onboarding/stats
Authorization: Bearer {token}

Response: RestaurantStats
```

### Login

```typescript
POST /auth/login
Content-Type: application/json

Body: {
  email: "restaurant@example.com",
  password: "SecurePass123!"
}

Response: {
  accessToken?: string,
  onboardingToken?: string,
  user: {
    id: string,
    email: string,
    role: "RESTAURANT",
    status: "APPROVED"
  }
}
```

## Dépendances

```json
{
  "react": "^19.2.0",
  "react-dom": "^19.2.0",
  "react-router-dom": "^6.20.1",
  "tailwindcss": "^4.1.18"
}
```

## Défaut de la mise en œuvre

- ⚠️ Pas de refresh automatique (à implémenter)
- ⚠️ Pas de gestion d'erreur réseau complète
- ⚠️ % changement meals saved est statique (à ajouter au backend)

## Prochaines étapes

1. [ ] Ajouter un refresh automatique toutes les 5 minutes
2. [ ] Implémenter pagination/filtres
3. [ ] Ajouter des graphiques (Chart.js, Recharts)
4. [ ] Exporter les données en PDF/CSV
5. [ ] Ajouter des notifications pour les offres
6. [ ] Implémenter un système de messages

## Test Credentials (si disponible)

Utilisez les credentials de restaurant depuis le backend :

```
Email: restaurant@example.com
Password: ValidPassword123!
```

## Troubleshooting

### "Failed to load restaurant stats"

**Cause:** Token invalide/expiré ou endpoint inaccessible
**Solution:** 
- Vérifiez le token dans localStorage
- Vérifiez que le backend écoute sur le bon port
- Vérifiez les CORS settings du backend

### CORS Error

**Cause:** Frontend et backend ne sont pas sur le même domaine
**Solution:**
- Vérifiez `VITE_API_URL`
- Vérifiez les CORS actives dans le backend

### 401 Unauthorized

**Cause:** Token expiré ou invalide
**Solution:**
- Logout et reconnectez-vous
- Vérifiez que l'endpoint `/restaurant/onboarding/stats` n'a pas de guards trop stricts

## Architecture File Structure

```
frontend-web/restaurant/
├── src/
│   ├── api/
│   │   └── restaurantApi.ts       # API service
│   ├── components/
│   │   └── Dashboard.tsx          # Dashboard component
│   ├── pages/
│   │   └── DashboardPage.tsx      # Dashboard page
│   ├── App.tsx                    # Main app with login
│   ├── main.tsx
│   └── index.css
├── .env                           # Environment variables
├── vite.config.ts
├── tsconfig.json
└── package.json
```

## Performance Notes

- Stats sont chargés une seule fois au mount
- Considérez un interval pour les reloads automatiques
- Utilisez React Query ou SWR pour le caching

## Sécurité

- ✅ JWT tokens en localStorage
- ✅ Tokens inclus dans headers Authorization
- ✅ HTTPS recommandé en production
- ⚠️ localStorage pas souhaitable pour prod (utiliser httpOnly cookies)

---

**Version:** 1.0.0  
**Last Updated:** April 19, 2026
