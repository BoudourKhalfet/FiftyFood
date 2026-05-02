# FiftyFood Recommendation System

## Overview

The recommendation system personalises the client's offer feed on the Available Offers page. It ranks offers by relevance using a hybrid approach that combines **one AI technique** (collaborative filtering) with **smart rule-based scoring** and **implicit interest tracking**.

All computation runs **server-side in NestJS** — no external API calls, no ML model hosting, completely free.

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                  Flutter Mobile App                  │
│                                                      │
│  ┌──────────────┐  ┌───────────┐  ┌───────────────┐ │
│  │AvailableOffers│  │OfferDetails│  │RestaurantDetails│
│  │    Page       │  │   Page    │  │     Page      │ │
│  └──────┬───────┘  └─────┬─────┘  └──────┬────────┘ │
│         │                │               │           │
│    GET /offers/     POST /interactions/ POST /interactions/
│    recommended      offer-view         restaurant-view
└─────────┬────────────────┬───────────────┬───────────┘
          │                │               │
┌─────────▼────────────────▼───────────────▼───────────┐
│                    NestJS Backend                     │
│                                                       │
│  ┌────────────────────────────────────────────────┐   │
│  │          RecommendationService                 │   │
│  │                                                │   │
│  │  1. Fetch active offers                        │   │
│  │  2. Build client signals (orders+views+price)  │   │
│  │  3. Collaborative filtering (AI)               │   │
│  │  4. Score every offer (11 scoring factors)     │   │
│  │  5. Sort by score, return top N                │   │
│  └────────────────────────────────────────────────┘   │
│                                                       │
│  ┌────────────────────────────────────────────────┐   │
│  │          InteractionsController                │   │
│  │  POST /interactions/offer-view                 │   │
│  │  POST /interactions/restaurant-view            │   │
│  └────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────┘
```

---

## Scoring Factors & Weights

All weights sum to **1.0**. Each factor produces a normalised score between 0 and 1, multiplied by its weight.

### AI Component (20%)

| Factor | Weight | Type | Description |
|--------|--------|------|-------------|
| **Collaborative filtering** | 0.20 | AI | Finds clients who ordered the same offers as the current client, then recommends what *those* clients also ordered. Uses viewed offers as additional seeds. Sigmoid saturation prevents any single signal from dominating. |

### Implicit Interest Tracking (20%)

| Factor | Weight | Type | Description |
|--------|--------|------|-------------|
| **Viewed categories** | 0.12 | Rule-based | Boosts offers whose categories match categories the client recently browsed (last 30 days). Uses log-scale for diminishing returns. |
| **Viewed restaurant** | 0.08 | Rule-based | Boosts offers from restaurants the client has visited (checked details page). |

### Price Sensitivity (8%)

| Factor | Weight | Type | Description |
|--------|--------|------|-------------|
| **Price match** | 0.08 | Rule-based | Computes client's average order price from history. Scores higher when offer price is close to that average. Tolerance band = ±50% of avg. |

### Preference & History (32%)

| Factor | Weight | Type | Description |
|--------|--------|------|-------------|
| **Cuisine preference match** | 0.15 | Rule-based | Matches offer categories against client's `cuisinePreferences` set during onboarding. |
| **Order history categories** | 0.10 | Rule-based | Matches offer categories against categories from past orders. Log-scale weighting gives more weight to frequently ordered categories. |
| **Restaurant repeat** | 0.07 | Rule-based | Boosts offers from restaurants the client has ordered from before. |

### Contextual (17%)

| Factor | Weight | Type | Description |
|--------|--------|------|-------------|
| **Proximity** | 0.08 | Rule-based | Haversine distance between client's last known location and restaurant. Linear decay: 0 km → score 1.0, 20+ km → score 0. |
| **Rating** | 0.05 | Rule-based | Restaurant's average rating (0–5) normalised to 0–1. |
| **Discount** | 0.04 | Rule-based | Higher discount percentage = higher score. |

### Exploration (3%)

| Factor | Weight | Type | Description |
|--------|--------|------|-------------|
| **Discovery bonus** | 0.03 | Rule-based | Small bonus for restaurants the client has never ordered from AND never viewed. Prevents filter bubbles. |

---

## Data Sources

| Data | Source | Used For |
|------|--------|----------|
| Client cuisine preferences | `ClientProfile.cuisinePreferences` | Preference matching |
| Client location | `ClientProfile.lastLatitude/lastLongitude` | Proximity scoring |
| Order history | `Order` table (last 200 orders) | Category matching, restaurant repeat, price sensitivity, collaborative filtering seeds |
| Offer views | `ClientInteraction` table (OFFER_VIEW, last 30 days) | Implicit interest categories, collaborative filtering seeds |
| Restaurant views | `ClientInteraction` table (RESTAURANT_VIEW, last 30 days) | Implicit interest restaurant boost |
| Offer data | `Offer` table (ACTIVE, quantity > 0) | Categories, price, restaurant |
| Restaurant ratings | `RestaurantProfile.avgRating` | Rating score |

---

## Database Model

```prisma
enum InteractionType {
  OFFER_VIEW
  RESTAURANT_VIEW
}

model ClientInteraction {
  id              String          @id @default(cuid())
  clientId        String
  interactionType InteractionType
  offerId         String?
  restaurantId    String?
  categories      String[]        @default([])
  price           Float?
  createdAt       DateTime        @default(now())

  @@index([clientId, interactionType])
  @@index([clientId, createdAt])
}
```

---

## API Endpoints

### GET /offers/recommended (Authenticated)

Returns personalised offer feed for the current client.

**Response:**
```json
[
  {
    "offer": {
      "id": "abc123",
      "description": "Delicious pizza...",
      "categories": ["PIZZA"],
      "originalPrice": 12.00,
      "discountedPrice": 7.50,
      "restaurant": {
        "id": "rest1",
        "restaurantProfile": {
          "restaurantName": "Pizza Palace",
          "avgRating": 4.5,
          "latitude": 36.75,
          "longitude": 3.05
        }
      }
    },
    "score": 0.6523,
    "reasons": [
      "Popular with similar customers",
      "Matches your preferences: PIZZA",
      "Nearby restaurant"
    ]
  }
]
```

### POST /interactions/offer-view (Authenticated)

Tracks when a client views offer details.

**Body:**
```json
{
  "offerId": "abc123",
  "categories": ["PIZZA", "FAST_FOOD"],
  "price": 7.50
}
```

### POST /interactions/restaurant-view (Authenticated)

Tracks when a client views a restaurant's details page.

**Body:**
```json
{
  "restaurantId": "rest1"
}
```

---

## Files

### Backend

| File | Purpose |
|------|---------|
| `backend/src/recommendations/recommendation.service.ts` | Core recommendation engine with scoring, collaborative filtering, and interaction tracking |
| `backend/src/recommendations/recommendation.module.ts` | NestJS module (exports RecommendationService, registers InteractionsController) |
| `backend/src/recommendations/interactions.controller.ts` | REST endpoints for tracking offer/restaurant views |
| `backend/src/offers/offers.controller.ts` | Added `GET /offers/recommended` endpoint |
| `backend/src/offers/offers.module.ts` | Imports RecommendationModule |
| `backend/src/prisma/schema.prisma` | Added `ClientInteraction` model and `InteractionType` enum |

### Mobile App (Flutter)

| File | Change |
|------|--------|
| `mobile_app/lib/screens/client/available_offers.dart` | `fetchOffers()` tries `/offers/recommended` first (auth), falls back to `/offers` (public) |
| `mobile_app/lib/screens/client/offer_details.dart` | Fires `POST /interactions/offer-view` on page load |
| `mobile_app/lib/screens/client/restaurant_details.dart` | Fires `POST /interactions/restaurant-view` on page load |

---

## Setup

After pulling these changes, run:

```bash
cd backend
npx prisma migrate dev --name add_client_interaction
npx prisma generate
```

This creates the `ClientInteraction` table and regenerates the Prisma client.

No additional environment variables or external APIs are required.

---

## How It Improves Over Time

1. **New client (no data):** Falls back to proximity + rating + discount + exploration bonus. Every restaurant has a fair chance.
2. **Client with preferences only:** Cuisine preference matching kicks in immediately after onboarding.
3. **Client starts browsing:** Implicit interest tracking starts influencing recommendations within the same session.
4. **Client makes first orders:** Order history, price sensitivity, and restaurant repeat signals activate.
5. **More users on the platform:** Collaborative filtering becomes increasingly accurate as the user-item interaction matrix grows.

---

## What Is AI vs What Is Not

| Component | AI? | Why |
|-----------|-----|-----|
| Collaborative filtering | **Yes** | Discovers hidden patterns from collective user behaviour that no hand-written rule can express. This is the same technique used by Netflix, Amazon, and Spotify. |
| Implicit interest tracking | No | Records events and matches categories — rule-based |
| Price sensitivity | No | Computes average and measures distance — arithmetic |
| Cuisine preference match | No | Set intersection — rule-based |
| Order history match | No | Frequency counting with log-scale — statistical heuristic |
| Proximity | No | Haversine formula — geometry |
| Rating / Discount | No | Direct value mapping — rule-based |
| Exploration bonus | No | Checks absence in sets — rule-based |

**Bottom line:** Collaborative filtering (20% weight) is the genuine AI component. Everything else is smart engineering that complements the AI to provide good recommendations even when collaborative data is sparse.

---

## Tuning

All weights are defined in `recommendation.service.ts` in the `W` constant object. To adjust:

1. Modify the weight values (ensure they sum to 1.0)
2. Restart the backend

No migration or rebuild is needed for weight changes.

### Current Weights (demo-optimised)

The weights are tuned for **academic demonstration** — the most visible/demonstrable factors have the highest weights so that evaluators can clearly see the system reacting to user behaviour during a live demo.

| Factor | Weight | Demo strategy |
|--------|--------|---------------|
| Collaborative filtering | 0.20 | The AI selling point |
| Cuisine preference match | 0.20 | Change preferences → feed reorders instantly |
| Viewed categories | 0.15 | Browse pizza offers → more pizza appears |
| Viewed restaurant | 0.10 | Check a restaurant → its offers rank higher |
| Order history categories | 0.10 | Order sushi → sushi offers rise in feed |
| Price match | 0.08 | Feed adjusts to client's spending habits |
| Proximity | 0.05 | Nearby offers rank slightly higher |
| Restaurant repeat | 0.05 | Returning to known restaurants |
| Rating | 0.03 | High-rated restaurants get a small boost |
| Discount | 0.02 | Good deals surface slightly |
| Exploration | 0.02 | New restaurants get a discovery bonus |

### Tuning by App Stage

| Stage | Strategy |
|-------|----------|
| **Launch (few users)** | Increase `CUISINE_PREF_MATCH`, `PROXIMITY`, `EXPLORATION` — these work without order history |
| **Growing (dozens of users)** | Current balanced weights work well |
| **Mature (hundreds+ users)** | Increase `COLLABORATIVE` to 0.30+ — it becomes more accurate with more data |

### Why Not Auto-Updating Weights?

The weights are **hyperparameters** (like learning rate in a neural network). Auto-tuning them requires:

- **Feedback data**: tracking whether clients actually click/order recommended offers
- **A reward signal**: defining what "good recommendation" means (click? order? repeat order?)
- **A training loop**: gradient descent or bandit algorithms to optimise weights

This is called **learned-to-rank** and is a real ML technique used in production systems. However, it requires thousands of recommendation → action events to be statistically meaningful, which is outside the scope of this prototype.

**What the system DOES adapt automatically:**
- Collaborative filtering improves as more users make orders (richer user-item matrix)
- Implicit interest tracking adjusts recommendations within a single session (browse pizza → pizza rises)
- Price sensitivity recalculates as client's order history grows

The system adapts its **scores** to user behaviour. The weights that balance those scores are fixed hyperparameters.

### A/B Testing (Production Technique)

A/B testing is how production systems (Netflix, Amazon, Spotify) optimise recommendation weights:

1. Split users into two groups randomly
2. **Group A** uses weight set A, **Group B** uses weight set B
3. Run for 1–2 weeks, measure click-through rate and conversion rate
4. Keep the weight set that performs better

**Example:**
```
Group A: COLLABORATIVE=0.20, CUISINE_PREF=0.20 → 30 orders from recommendations
Group B: COLLABORATIVE=0.35, CUISINE_PREF=0.10 → 52 orders from recommendations
→ Group B wins → adopt those weights for everyone
```

**Why it doesn't apply here:** A/B testing requires thousands of real user interactions to produce statistically significant results, plus infrastructure to run two parallel recommendation pipelines. This is a production optimisation technique, not applicable to an academic prototype.

> **For the academic report:** "The recommendation engine adapts to user behaviour through implicit interest tracking and collaborative filtering. The scoring weights are configurable hyperparameters. In a production setting, these could be optimised via A/B testing or learned-to-rank models, but this is outside the scope of this prototype."

---

## Demo Script

### Preparation

1. Create **2 client accounts** with different cuisine preferences:
   - **Client A**: preferences = `PIZZA, FAST_FOOD`
   - **Client B**: preferences = `SUSHI, ASIAN`
2. Create **3+ restaurant accounts** with diverse offers:
   - Restaurant 1: Pizza offers (€5–€8)
   - Restaurant 2: Sushi offers (€10–€15)
   - Restaurant 3: Burger offers (€6–€9)

### Step 1: Preference-Based Recommendations

| Action | Expected Result |
|--------|----------------|
| Log in as **Client A** (PIZZA, FAST_FOOD) | Pizza and burger offers appear at the top |
| Log in as **Client B** (SUSHI, ASIAN) | Sushi offers appear at the top |

**Script:** "The same set of offers is ranked differently for each client based on their cuisine preferences."

### Step 2: Implicit Interest Tracking

| Action | Expected Result |
|--------|----------------|
| As Client A, note the current offer order | Baseline |
| Tap into a **sushi offer** details page | Fires an offer-view event |
| Go back, tap into the **sushi restaurant** details | Fires a restaurant-view event |
| Return to Available Offers, **pull to refresh** | Sushi offers have moved **higher** in the feed |

**Script:** "The client browsed sushi content. Without placing an order, the system detected implicit interest and boosted sushi offers in the feed."

### Step 3: Collaborative Filtering (AI)

| Action | Expected Result |
|--------|----------------|
| As **Client A**, order a **Pizza Margherita** | Order placed |
| As **Client B**, also order that **same Pizza Margherita** | Both clients share order history |
| As **Client B**, also order a **Burger offer** | Client B has pizza + burger |
| Log back in as **Client A**, refresh Available Offers | The **Burger offer** ranks higher than before |

**Script:** "Client A and Client B both ordered the same pizza. Client B also ordered a burger. The collaborative filtering algorithm detected this pattern and recommended the burger to Client A — because similar customers liked it. This is the same technique used by Netflix and Amazon."

### Step 4: Score Transparency (proving the system works with numbers)

This is the most important demo step. The `GET /offers/recommended` API returns the **raw score and human-readable reasons** for every recommended offer.

**How to show it:**

1. Open **Postman** (or browser dev tools → Network tab)
2. Send a `GET` request to `http://localhost:3000/offers/recommended`
3. Add the header: `Authorization: Bearer <Client A's JWT token>`
4. Show the JSON response

**Example response (what evaluators will see):**

```json
[
  {
    "offer": {
      "id": "offer_1",
      "description": "Margherita Pizza - fresh mozzarella...",
      "categories": ["PIZZA"],
      "originalPrice": 12.00,
      "discountedPrice": 7.50,
      "restaurant": {
        "restaurantProfile": {
          "restaurantName": "Pizza Palace",
          "avgRating": 4.5
        }
      }
    },
    "score": 0.6523,
    "reasons": [
      "Popular with similar customers",
      "Matches your preferences: PIZZA",
      "Similar to offers you've been browsing",
      "In your usual price range",
      "Highly rated"
    ]
  },
  {
    "offer": {
      "id": "offer_2",
      "description": "Classic Cheeseburger...",
      "categories": ["FAST_FOOD"],
      "originalPrice": 10.00,
      "discountedPrice": 6.00
    },
    "score": 0.4210,
    "reasons": [
      "Popular with similar customers",
      "Matches your preferences: FAST_FOOD",
      "Great deal"
    ]
  },
  {
    "offer": {
      "id": "offer_3",
      "description": "Salmon Sushi Set...",
      "categories": ["SUSHI"],
      "originalPrice": 18.00,
      "discountedPrice": 13.00
    },
    "score": 0.1850,
    "reasons": [
      "Similar to offers you've been browsing",
      "From a restaurant you checked out",
      "New restaurant to discover"
    ]
  }
]
```

**What to point out to evaluators:**

- **Scores decrease** from top to bottom — the system ranks by relevance
- **Offer 1** (Pizza, score 0.65): highest because it matches preferences, collaborative filtering detected similar users, AND the client browsed pizza content
- **Offer 2** (Burger, score 0.42): mid-rank because collaborative filtering surfaced it (similar customers ordered it) and it matches FAST_FOOD preference
- **Offer 3** (Sushi, score 0.19): lowest for Client A, but NOT zero — it appears because the client browsed sushi content earlier (implicit interest) and gets the exploration bonus
- **Reasons array** makes the system **explainable** — each recommendation can justify itself

**Key comparison to show:**

Call the same endpoint with **Client B's JWT** and show that the **exact same offers** now have **different scores and different order**:

```
Client A: Pizza (0.65) → Burger (0.42) → Sushi (0.19)
Client B: Sushi (0.58) → Burger (0.31) → Pizza (0.22)
```

**Script:** "The API returns a score and a list of reasons for each offer. This makes the recommendation system fully transparent and explainable. The same three offers are ranked differently for each client. The reasons tell us exactly why — Client A gets pizza first because of preference matching and collaborative filtering. Client B gets sushi first because of their preferences. The system is personalised, explainable, and adaptive."

### Side-by-side Screenshot (for slides)

```
Client A (PIZZA lover)          Client B (SUSHI lover)
┌──────────────────┐            ┌──────────────────┐
│ 1. Pizza Special │            │ 1. Sushi Combo   │
│    score: 0.65   │            │    score: 0.58   │
│ 2. Burger Deal   │            │ 2. Burger Deal   │
│    score: 0.42   │            │    score: 0.31   │
│ 3. Sushi Combo   │            │ 3. Pizza Special │
│    score: 0.19   │            │    score: 0.22   │
└──────────────────┘            └──────────────────┘
```
