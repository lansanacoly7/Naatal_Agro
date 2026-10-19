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
POST /api/agriculture/crops/
Authorization: Bearer <token>
```

```json
{
  "name": "Oignon Violet de Galmi",
  "crop_type": "Oignon",
  "planting_date": "2026-01-15",
  "expected_harvest_date": "2026-05-15",
  "status": "active",
  "area_size": 2.5,
  "location": "Thiès, Sénégal",
  "guide": "<uuid_optionnel_fiche_agronomique>"
}
```

> **Règle de validation (zéro donnée inventée)** : Si un `guide` agronomique documenté avec cycle (`cycle_days_min/max`) est fourni, la date `expected_harvest_date` peut être automatiquement calculée à partir de `planting_date`. Dans le cas contraire, `expected_harvest_date` est **strictement obligatoire** (aucun cycle arbitraire de 90 jours n'est attribué par défaut).

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

## 7.3 Fiches agronomiques (lecture seule)

```http
GET /api/agriculture/guides/                 # liste (accepte ?category=legume|cereale|legumineuse|fruit et ?search=)
GET /api/agriculture/guides/<slug>/          # détail : 19 fiches (voir la liste ci-dessous)
```

Chaque fiche contient : `name`, `scientific_name`, `category`, `summary`, `zones`, `cycle_days_min/max`, `calendar`,
`soil_and_sowing`, `water_needs`, `fertilization`, `pests_diseases` (liste de `{name, advice}`), `harvest`, `yield_info`,
`limitations` et `sources` (liste de `{title, publisher, year, url}`).

Fiches disponibles (`slug`) et niveau des sources :

| Catégorie | Fiches | Sources principales |
|---|---|---|
| Légumes | `oignon`, `carotte` (guides du ministère, PIESAN, 2022) ; `tomate-industrielle` (SAED, 2021) ; `pomme-de-terre`, `chou`, `aubergine`, `piment`, `gombo`, `patate-douce`, `melon`, `bissap` (bilan ISRA/ITA/CIRAD, 2005) | Sénégal |
| Céréales | `mil`, `riz-irrigue`, `sorgho`, `mais` | Sénégal (ISRA, CIRAD, DAPSA, SAED) |
| Légumineuses et tubercules | `arachide` (ISRA/CIRAD 1997 et IFDC 2019, ce dernier hors Sénégal), `niebe`, `manioc` | Sénégal, sauf mention |
| Fruits | `mangue` (CIRAD, 2017) | Sénégal |

Chaque source porte un champ `scope` : `senegal` (décrit des pratiques ou résultats au Sénégal), `west_africa` ou `international`
(référence régionale, à adapter). L'assistant signale toute réponse qui s'appuie sur une source hors Sénégal.
Les sources de 2005 ne reprennent volontairement aucun nom de pesticide : plusieurs produits cités à l'époque sont aujourd'hui interdits.

**Règles de contenu** (testées automatiquement) :

- Un champ vide signifie « non documenté par nos sources », jamais une valeur devinée.
- Chaque texte rempli porte un repère `[n]` qui renvoie à la n-ième entrée de `sources`.
- Chaque fiche indique ses `limitations` (par exemple une source ancienne ou un essai sur une seule saison).
- Les fiches sont dans `backend/apps/agriculture/data/agronomic_guides.json`. Elles sont synchronisées automatiquement après chaque
  `python manage.py migrate` (fiches modifiées depuis l'administration conservées) ; `python manage.py load_agronomic_guides [--force]`
  relance la synchronisation à la demande.

Les fiches sont des repères d'information, pas des prescriptions : les produits phytosanitaires et les doses doivent être
confirmés auprès d'un conseiller agricole (ANCAR, SAED, ISRA) et des produits autorisés par la législation.

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

## Latest prices (un relevé par marché)

```http
GET /api/markets/prices/latest/?product=Oignon
```

Dernier relevé de prix de **chaque marché** pour un produit : une ligne par marché, triée par nom de marché.
Sert à la carte des marchés et au classement « meilleur marché ».

- `product` est **requis** (recherche partielle, insensible à la casse) ; `400` si absent ou vide.
- Réponse : tableau JSON **non paginé** (un objet par marché) :

```json
[
  {
    "market": "uuid",
    "market_name": "Marché de Thiès",
    "region": "Thiès",
    "location_gps": "14.79,-17.44",
    "product_name": "Oignon Local",
    "price": 450.0,
    "trend": "up",
    "date": "2026-10-14"
  }
]
```

---

## Price history (historique journalier)

```http
GET /api/markets/prices/history/?product=Oignon&market=<id>&days=30
```

Série journalière d'un produit, sur les `days` derniers jours glissants à partir du relevé le plus récent.

- `product` : requis, recherche partielle (insensible à la casse) ; `400` si absent ou vide.
- `market` (facultatif) : identifiant d'un marché. Sans ce paramètre, la série est la **moyenne de tous les marchés**
  ce jour-là ; avec, les relevés de ce marché seul.
- `days` (facultatif) : 30 par défaut, borné entre 1 et 120 ; valeur non numérique : `400`.
- Aucun relevé pour le produit : tableau vide `[]`.

```json
[
  { "date": "2026-10-12", "price": 425.5, "markets": 3 },
  { "date": "2026-10-13", "price": 450.0, "markets": 4 }
]
```

`price` est la moyenne (ou le prix du marché demandé) arrondie à 2 décimales ; `markets` est le nombre de marchés
ayant un relevé ce jour-là.

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
POST /api/ai/ask/        # poser une question
GET  /api/ai/ask/        # 20 derniers échanges de l'utilisateur
```

```json
{ "query": "Comment semer les tomates ?", "context": "agriculture" }
```

`query` : texte de 1000 caractères maximum. `image_base64` (facultatif) : photo pour un diagnostic. Limite : 30 questions par heure.

## AI Response

Réponse `201` (le champ `response` est le texte à afficher, sources comprises) :

```json
{
  "id": "uuid",
  "query": "Comment semer les tomates ?",
  "response": "Tomate industrielle : Semis et calendrier\n... [1]\n\nSources :\n[1] Livrable 3 : note de synthèse...",
  "origin": "database",
  "sources": [
    { "number": 1, "title": "...", "publisher": "...", "year": "2021", "url": "https://...", "type": "fiche" }
  ],
  "context_type": "agriculture",
  "created_at": "2026-10-05T20:00:00Z"
}
```

`origin` indique d'où vient la réponse :

| Valeur | Sens |
|---|---|
| `database` | Réponse construite à partir de nos fiches agronomiques, avec leurs sources (`/api/agriculture/guides/`) |
| `general` | Conseil général sans source (culture absente de nos fiches, photo, ou sujet non documenté). L'application doit l'afficher comme tel |

`origin` et `sources` sont fixés par le serveur : un client ne peut pas les envoyer.

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
GET /api/dashboard/
Authorization: Bearer <access>
```

Endpoint d'agrégation : cultures, prix des cultures de l'utilisateur, météo de sa région, stocks, calendrier,
produits tendance et alertes, en une seule requête. Accès : connecté (`IsAuthenticated`).

---

## Response

Réponse `200` (tableau/objets JSON directement, sans enveloppe) :

```json
{
  "agriculture": {
    "active_crops_count": 3,
    "total_area_size": 4.5
  },
  "markets": [
    {
      "product_name": "oignon local",
      "price": 450.0,
      "min_price": 400.0,
      "max_price": 520.0,
      "markets_count": 4,
      "date": "2026-10-14",
      "change_percent": 2.5,
      "trend": "up",
      "market__name": "4 marchés"
    }
  ],
  "weather": {
    "location": "Thiès, Sénégal",
    "temp": 28.5,
    "humidity": 70.0,
    "rainfall": 12.0,
    "date": "2026-10-14"
  },
  "alerts": [],
  "stockItems": [],
  "calendarEvents": [],
  "featuredProducts": []
}
```

### `markets` — prix des cultures de l'utilisateur

Pour chaque produit que l'utilisateur cultive ou suit (noms de ses cultures, de leur type et `main_crops`,
3 caractères minimum, 12 produits au maximum, 6 résultats renvoyés) : le relevé le plus récent, **tous marchés
confondus** (moyenne à la date du dernier relevé).

| Champ | Sens |
|---|---|
| `product_name` | Nom du produit (tel que renvoyé par le relevé) |
| `price` | Moyenne des prix de tous les marchés à la date du relevé le plus récent, arrondie à 2 décimales |
| `min_price` | Prix le plus bas relevé ce jour-là |
| `max_price` | Prix le plus haut relevé ce jour-là |
| `markets_count` | Nombre de marchés ayant donné un prix ce jour-là |
| `date` | Date du relevé (`AAAA-MM-JJ`) |
| `change_percent` | Évolution en % par rapport au relevé d'au moins 7 jours avant (arrondie à 0,1) ; `null` si aucun relevé assez ancien |
| `trend` | `up` si `change_percent` > 1 %, `down` si < −1 %, sinon `stable` |
| `market__name` | Libellé du nombre de marchés (« 4 marchés ») |

Liste vide si l'utilisateur ne cultive rien ou si aucun prix n'existe.

### `weather` — météo de la région de l'utilisateur

Relevé le plus récent de la **région de l'utilisateur uniquement** (première partie de son `location` avant la
virgule) : `location`, `temp`, `humidity`, `rainfall` et `date` (date de prévision, **nouveau champ** ; côté client,
l'absence de `temp` signale qu'aucune météo n'est disponible). Objet `{}` si aucune donnée pour sa région.

### Autres clés

| Clé | Contenu |
|---|---|
| `agriculture` | `{active_crops_count, total_area_size}` (cultures dont le statut est `active`) |
| `alerts` | Jusqu'à 5 notifications non lues : `{id, type, message, created_at}` |
| `stockItems` | Éléments de stock : `{id, name, quantity, unit, alert_status, ai_storage_advice, updated_at}` |
| `calendarEvents` | 5 prochaines activités : `{title, description, date ("14\nOCT"), phase}` (nom de la culture) |
| `featuredProducts` | 5 produits tendance (`is_trending`, sinon les 5 premiers) : `{id, name, category, price, trend_percentage, imageAsset}` |

---

# 12.1 Confidentialité (données personnelles)

| Point d'accès | Méthode | Accès | Rôle |
|---|---|---|---|
| `/api/privacy/policy/` | GET | public | Texte de la politique de confidentialité et sa version |
| `/api/privacy/export/` | GET | connecté | Export JSON de toutes les données du compte (droit d'accès) |
| `/api/privacy/delete-account/` | POST | connecté | Suppression définitive du compte et des données liées (droit à l'effacement) |

- **Consentement** : l'inscription accepte `privacy_accepted: true`. La date et la version acceptées sont enregistrées sur le compte.
  Le réglage `PRIVACY_CONSENT_REQUIRED` (variable d'environnement, `False` par défaut) rend ce champ obligatoire ; à activer
  quand l'application mobile affichera la case à cocher.
- **Export** : réponse `200` avec `Content-Disposition: attachment`. Contient profil, cultures, activités, signalements,
  ventes, transactions, stocks, notifications et échanges IA du compte, jamais ceux d'un autre utilisateur ni le mot de passe.
- **Suppression** : corps `{ "password": "..." }` ; `204` si le mot de passe est correct, `400` sinon, `403` pour un compte
  d'administration. Toutes les données liées sont effacées (cascade).
- Le texte de `apps/privacy/policy_fr.md` est un document de travail : l'identité du responsable du traitement et le contact
  doivent être ajoutés par le propriétaire du projet, et le texte validé juridiquement avant publication.

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


