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

Contrat réellement implémenté (préfixe `/api/users/`). Les identifiants sont le **numéro de téléphone** au
format international (`+221771234567`) ; les espaces, points et tirets saisis sont ignorés.

| Point d'accès | Méthode | Accès | Rôle |
|---|---|---|---|
| `/api/users/auth/register/` | POST | public | Création d'un compte agriculteur |
| `/api/users/auth/login/` | POST | public | Obtention des jetons |
| `/api/users/auth/refresh/` | POST | public (avec refresh) | Renouvellement (rotation) |
| `/api/users/auth/logout/` | POST | connecté | Invalidation du refresh token |
| `/api/users/auth/password/change/` | POST | connecté | Changement de mot de passe |

Limite de débit : 10 requêtes par minute sur register, login et changement de mot de passe (scope `auth`).

---

## 5.1 Register

```http
POST /api/users/auth/register/
```

```json
{
  "phone_number": "+221771234567",
  "full_name": "Fatou Sow",
  "password": "Motdepasse#2026",
  "language": "fr",
  "location": "Saint-Louis, Sénégal",
  "role": "farmer",
  "main_crops": ["Riz"]
}
```

- `phone_number`, `full_name`, `password` obligatoires ; `role` ne peut valoir que `farmer` (un compte
  administrateur ne se crée pas par l'inscription publique).
- Réponses : `201` création ; `400` numéro invalide (`phone_number`), numéro déjà utilisé, mot de passe refusé (`password`).
- **Politique de mot de passe** : 8 caractères minimum, pas uniquement numérique, pas dans la liste des mots de passe
  courants, pas trop proche du nom ou du numéro.

---

## 5.2 Login

```http
POST /api/users/auth/login/
```

```json
{ "phone_number": "+221771234567", "password": "Motdepasse#2026" }
```

Réponse `200` :

```json
{
  "access": "jwt (validité 1 jour)",
  "refresh": "jwt (validité 7 jours)",
  "role": "farmer",
  "location": "Thiès, Sénégal",
  "full_name": "Fatou Sow"
}
```

Mauvais identifiants : `401`, sans préciser si le numéro existe.

---

## 5.3 Refresh token (rotation)

```http
POST /api/users/auth/refresh/
```

```json
{ "refresh": "jwt" }
```

Réponse `200` : un nouvel `access` **et un nouveau `refresh`**. L'ancien `refresh` est invalidé immédiatement :
le client doit conserver le nouveau. Un refresh déjà utilisé ou invalidé donne `401`.

---

## 5.4 Logout

```http
POST /api/users/auth/logout/
Authorization: Bearer <access>
```

```json
{ "refresh": "jwt" }
```

`204` : le refresh est invalidé. `400` jeton absent ou invalide ; `403` jeton d'un autre utilisateur.

---

## 5.5 Changement de mot de passe

```http
POST /api/users/auth/password/change/
Authorization: Bearer <access>
```

```json
{ "old_password": "Motdepasse#2026", "new_password": "Autre#Mdp2027" }
```

`204` : mot de passe changé et **toutes les sessions ouvertes sont fermées** (le client doit se reconnecter).
`400` : mot de passe actuel incorrect, nouveau mot de passe refusé par la politique, ou identique à l'actuel.

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

* pagination : implémentée **à la demande** (voir §13.4), à rendre obligatoire quand le mobile l'utilisera partout
* requêtes optimisées ORM
* cache (Redis futur)
* endpoint dashboard optimisé

---

## 13.3 Architecture interne

* séparation service / controller
* logique métier isolée
* API versionnable (/api/v1/)

---

## 13.4 Pagination

Toute liste accepte `?page=<n>` et `?page_size=<n>` (20 par défaut, 100 au maximum). Réponse paginée :

```json
{ "count": 57, "next": "http://.../?page=2", "previous": null, "results": [] }
```

Sans paramètre, la liste complète est renvoyée sous forme de tableau JSON (compatibilité avec les clients existants).
Une page hors limites répond `404`. L'ordre des résultats est déterministe (ordre par défaut de chaque modèle).

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


