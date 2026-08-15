
# 🌾 Nataal Agro — System Architecture

| Informations | Valeur |
|--------------|---------|
| Projet | Nataal Agro |
| Document | System Architecture |
| Version | 2.0 |
| Statut | Mise à jour |
| Dépend de | 03-UX-UI.md |
| Objectif | Définir l’architecture technique globale du système |

---

# 1. Vue d’ensemble du système

Nataal Agro est une architecture **modulaire client-serveur orientée domaine métier**.

Elle repose sur une séparation stricte entre :

- 📱 Frontend mobile (Flutter)
- 🌐 Frontend web (React - futur)
- ⚙️ Backend API (Django REST Framework)
- 🗄️ Base de données (PostgreSQL)
- 🤖 Services IA (Gemini + Groq)
- 🔔 Notifications (Firebase Cloud Messaging)

---

# 2. Architecture globale

```text id="arch_global_v2"
                ┌──────────────────────┐
                │   Flutter Mobile     │
                │ (Client principal)   │
                └─────────┬────────────┘
                          │ HTTPS / REST API
                          ▼
                ┌──────────────────────┐
                │   Django Backend     │
                │ (Core Business API)  │
                └─────────┬────────────┘
          ┌────────────────┼────────────────┐
          ▼                ▼                ▼
   PostgreSQL        IA Services       Firebase FCM
   (Data Layer)      (Intelligence)    (Notifications)
````

---

# 3. Principes d’architecture

---

## 3.1 Architecture orientée domaine (DDD léger)

Le backend est structuré par domaines métier :

```text id="domains_v2"
users
agriculture
markets
weather
ai
notifications
```

Chaque domaine est indépendant et scalable.

---

## 3.2 Séparation stricte des responsabilités

* Flutter → UI + state local
* Django → logique métier + règles + sécurité
* PostgreSQL → persistance
* IA → intelligence décisionnelle externe
* Firebase → communication temps réel

---

## 3.3 Scalabilité horizontale

Chaque module peut évoluer indépendamment sans impacter les autres.

---

# 4. Communication système

---

## 4.1 Flutter → Backend

* REST API (JSON)
* Auth JWT
* HTTPS obligatoire

Exemple :

```http id="api_example_v2"
GET /api/markets/prices
Authorization: Bearer <token>
```

---

## 4.2 Backend → Database

* Django ORM
* transactions sécurisées
* migrations contrôlées

---

## 4.3 Backend → IA (core du système)

Deux moteurs IA :

---

### 🧠 Gemini (analyse lourde)

* analyse agricole contextuelle
* recommandations complexes
* historique long utilisateur
* raisonnement multi-facteurs

---

### ⚡ Groq (réponses rapides)

* chat instantané
* réponses courtes
* assistant temps réel

---

## Flux IA :

```text id="ai_flow_v2"
User → Django API → AI Service Manager → (Gemini / Groq) → Response → Flutter
```

---

## 4.4 Backend → Firebase

Utilisé pour :

* notifications agricoles
* alertes météo
* alertes marché
* rappels de culture
* événements système

---

# 5. Architecture backend (Django)

---

## 5.1 Structure modulaire

Chaque domaine est une application Django indépendante :

```text id="django_modules_v2"
users/
agriculture/
markets/
weather/
ai/
notifications/
```

---

## 5.2 Description des modules

---

### 👤 users

* authentification JWT
* gestion profils
* rôles utilisateur
* préférences

---

### 🌱 agriculture

* cultures
* cycles agricoles
* activités
* récoltes

---

### 💰 markets

* marchés
* prix
* historique des prix
* tendances

---

### 🌦️ weather

* données météo
* prévisions
* alertes climatiques

---

### 🤖 ai

* orchestration IA
* gestion prompts
* agrégation contexte
* réponses intelligentes

---

### 🔔 notifications

* push notifications
* scheduling
* triggers métier

---

# 6. Flux utilisateur principal

```text id="user_flow_v2"
1. L’utilisateur ouvre l’application
2. Flutter appelle /dashboard
3. Django agrège :
   - météo
   - cultures
   - marchés
   - alertes
   - recommandations IA
4. Retour JSON unifié
5. Flutter affiche l’interface
```

---

# 7. Gestion des données

---

## 7.1 Modèle logique PostgreSQL

```text id="db_model_v2"
Users
AgriculturalProfile

Crops
CropActivities
Harvests

Markets
Prices

WeatherData

AIInteractions

Notifications
```

---

## 7.2 Isolation des données

Chaque utilisateur possède :

* ses cultures
* ses activités
* ses données marché associées
* ses interactions IA

---

# 8. Sécurité système

---

## 8.1 Authentification

* JWT access token
* refresh token
* expiration contrôlée

---

## 8.2 Protection API

* rate limiting
* permissions par rôle
* validation stricte des requêtes

---

## 8.3 Données sensibles

* chiffrement des tokens
* logs sécurisés
* séparation des environnements (dev / prod)

---

# 9. Performance système

---

## 9.1 Backend

* cache (Redis futur)
* optimisation ORM
* pagination obligatoire
* agrégation intelligente (/dashboard)

---

## 9.2 Mobile (Flutter)

* cache local
* réduction des appels API
* stockage offline partiel
* lazy loading UI

---

# 10. Gestion des erreurs

* format API standardisé :

```json id="error_format_v2"
{
  "success": false,
  "error": "message",
  "code": 400
}
```

* fallback côté Flutter
* logs backend centralisés

---

# 11. Scalabilité

Le système est conçu pour évoluer vers :

* marketplace agricole
* coopératives
* IA avancée (prédictive + vision)
* analyse satellite
* IoT agricole

---

# 12. Conclusion

L’architecture de Nataal Agro repose sur :

* séparation stricte des domaines métier
* backend central intelligent
* IA intégrée comme service critique
* frontend léger et rapide
* évolutivité complète du système

---

# 🧠 Résultat architecture

Nataal Agro est une plateforme :

> modulaire, scalable, orientée décision, avec une IA centrale et un backend structuré par domaine métier.

```

---

# 🧠 Ce qu’on vient d’améliorer (très important)

### ✔ vraie architecture DDD (plus propre pour un vrai produit)
### ✔ clarification IA (Gemini vs Groq)
### ✔ suppression des zones floues
### ✔ séparation claire responsabilités Flutter / Django
### ✔ backend prêt pour scaling réel
### ✔ structure compatible Antigravity / Cursor / dev team

