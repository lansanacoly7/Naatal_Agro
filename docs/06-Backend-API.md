# 🌾 Nataal Agro — Backend API Specification

| Informations | Valeur |
|--------------|---------|
| Projet | Nataal Agro |
| Document | Backend API |
| Version | 2.0 |
| Statut | Mise à jour |
| Dépend de | 05-Database-Design.md |
| Objectif | Définir une API structurée, scalable et maintenable |

---

# 1. Objectif du backend

Le backend de Nataal Agro est le **cerveau central du système**.

Il doit :

- centraliser la logique métier
- orchestrer les données (agriculture, marchés, météo, IA)
- sécuriser les accès utilisateurs
- fournir une API unifiée pour Flutter et React
- garantir scalabilité et robustesse

---

# 2. Architecture API (niveau production)

## Stack

- Django REST Framework
- JWT Authentication
- PostgreSQL
- Redis (futur cache)
- IA services (Gemini / Groq)

---

## 2.1 Style architectural

L’API suit un modèle :

> **Domain-driven API + Service Layer**

---

## 2.2 Structure logique API

```text id="api_structure_v2"
api/
 ├── auth/
 ├── users/
 ├── agriculture/
 ├── markets/
 ├── weather/
 ├── ai/
 ├── notifications/
 └── dashboard/
````

Chaque domaine = un module indépendant.

---

# 3. Base URL

```text id="api_base_v2"
https://api.nataalagro.com/api/
```

---

# 4. Standard de réponse API

Toutes les réponses doivent suivre ce format :

## Succès

```json id="api_success"
{
  "success": true,
  "data": {},
  "message": "optional"
}
```

## Erreur

```json id="api_error"
{
  "success": false,
  "error": {
    "message": "string",
    "code": 400
  }
}
```

---

# 5. Authentification (JWT)

---

## 5.1 Register

```http id="auth_register"
POST /auth/register/
```

```json
{
  "name": "string",
  "phone": "string",
  "password": "string"
}
```

---

## 5.2 Login

```http id="auth_login"
POST /auth/login/
```

```json
{
  "access_token": "jwt",
  "refresh_token": "jwt"
}
```

---

## 5.3 Refresh token

```http
POST /auth/refresh/
```

---

# 6. Users API

---

## Get profile

```http
GET /users/me/
Authorization: Bearer <token>
```

---

## Update profile

```http
PUT /users/me/
```

---

# 7. Agriculture API (Core métier)

---

## 7.1 Crops (Cultures)

### Create crop

```http
POST /agriculture/crops/
```

```json
{
  "name": "tomate",
  "category": "maraichage",
  "planting_date": "2026-01-01",
  "area_size": 2,
  "location": {
    "lat": 14.7,
    "lng": -17.4
  }
}
```

---

### Get all crops

```http
GET /agriculture/crops/
```

---

### Get crop details

```http
GET /agriculture/crops/{id}/
```

---

## 7.2 Crop Activities (journal agricole)

```http
POST /agriculture/crops/{id}/activities/
```

```json
{
  "type": "arrosage",
  "description": "Arrosage du matin"
}
```

---

# 8. Markets API (logique décisionnelle)

---

## Get markets

```http
GET /markets/
```

---

## Get prices

```http
GET /markets/prices?product=tomate
```

---

## Compare markets

```http
GET /markets/compare?product=tomate
```

---

# 9. Weather API

---

## Current weather

```http
GET /weather/?location=Thiès
```

---

## Forecast

```http
GET /weather/forecast/
```

---

# 10. AI API (Cœur intelligent)

---

## Ask AI

```http
POST /ai/ask/
```

```json
{
  "query": "Quand dois-je arroser mes tomates ?",
  "context": "agriculture",
  "crop_id": "optional"
}
```

---

## AI Response

```json
{
  "success": true,
  "data": {
    "answer": "Il est recommandé d’arroser tôt le matin pour éviter l’évaporation.",
    "model": "gemini",
    "confidence": 0.87
  }
}
```

---

# 11. Notifications API

---

## Get notifications

```http
GET /notifications/
```

---

## Mark as read

```http
POST /notifications/{id}/read/
```

---

# 12. Dashboard API (Ultra important)

---

## Aggregation endpoint

```http
GET /dashboard/
```

---

## Response

```json
{
  "success": true,
  "data": {
    "weather": {},
    "markets": [],
    "crops": [],
    "alerts": [],
    "recommendations": []
  }
}
```

---

# 13. Règles backend

---

## 13.1 Sécurité

* JWT obligatoire
* permissions par user
* validation stricte input
* rate limiting API

---

## 13.2 Performance

* pagination obligatoire
* requêtes optimisées ORM
* cache (Redis futur)
* endpoint dashboard optimisé

---

## 13.3 Architecture interne

* séparation service / controller
* logique métier isolée
* API versionnable (/api/v1/)

---

# 14. Gestion des erreurs

```json
{
  "success": false,
  "error": {
    "message": "Invalid request",
    "code": 400
  }
}
```

---

# 15. Scalabilité

Le backend est conçu pour évoluer vers :

* marketplace agricole
* coopératives
* IA multi-agents
* analyse satellite
* IoT agricole
* prédiction des rendements

---

# 16. Conclusion

Le backend de Nataal Agro est :

> un système central modulaire, orienté domaines métier, capable de gérer agriculture, marchés, IA et utilisateurs dans une architecture scalable et sécurisée.

```

---

# 🧠 Ce que j’ai corrigé (important)

### ✔ Ajout standard API response (CRITIQUE PRO)
### ✔ vraie séparation domain API
### ✔ ajout versioning mental (/api/v1 future)
### ✔ clarification IA response structure
### ✔ dashboard comme endpoint central intelligent
### ✔ correction géolocalisation JSON propre
### ✔ architecture service layer implicite
### ✔ cohérence avec Django scalable réel

---

# ⚠️ Point important (niveau pro)

Ton backend est maintenant :
- ❌ plus un simple CRUD API
- ✔ un **API orchestrateur de décision agricole**
- ✔ prêt pour Flutter industriel
- ✔ prêt pour IA intégrée sérieuse

---


