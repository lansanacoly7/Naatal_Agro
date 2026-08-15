# 🌾 Nataal Agro — Database Design (PostgreSQL)

| Informations | Valeur |
|--------------|---------|
| Projet | Nataal Agro |
| Document | Database Design |
| Version | 2.0 |
| Statut | Mise à jour |
| Dépend de | 04-Architecture-System.md |
| Objectif | Définir un modèle de données relationnel scalable |

---

# 1. Objectif de la base de données

La base de données de Nataal Agro doit :

- stocker les données agricoles utilisateurs
- gérer les cultures et leur cycle de vie complet
- centraliser les données de marché
- intégrer les données météo
- alimenter les modules IA
- garantir isolation et sécurité multi-utilisateurs
- rester scalable pour extension (IA, marketplace, IoT)

---

# 2. Choix technologique

- PostgreSQL (base principale)
- Django ORM (accès données)
- Extensions futures :
  - PostGIS (géolocalisation avancée)
  - Redis (cache performance)
  - TimescaleDB (données temporelles prix/météo)

---

# 3. Principes de conception

- normalisation (3NF minimum)
- séparation par domaine métier
- relations explicites
- optimisation lecture (read-heavy system)
- intégrité référentielle stricte
- scalabilité horizontale

---

# 4. Modèle global (Domain Driven Design)

La base est organisée par domaines :

```text id="db_domains_v2"
users
agriculture
markets
weather
ai
notifications
````

---

# 5. Schéma des entités principales

---

# 5.1 👤 USERS

## users_user

* id (UUID, PK)
* name
* phone (unique)
* password_hash
* language (fr / wo)
* location_lat
* location_lng
* created_at
* updated_at

---

## users_profile

* id (UUID)
* user_id (FK → users_user)
* role (farmer, trader, analyst)
* farm_size
* main_crops
* preferences_json

---

# 5.2 🌱 AGRICULTURE

## agriculture_crop

Représente une culture suivie par un utilisateur.

* id (UUID)
* user_id (FK)
* name (riz, maïs, tomate…)
* category (cereal, vegetable, fruit)
* planting_date
* expected_harvest_date
* status (active, harvested, lost)
* area_size
* location_lat
* location_lng
* created_at

---

## agriculture_crop_activity

Journal agricole (très critique pour IA)

* id
* crop_id (FK)
* activity_type (irrigation, fertilization, treatment, harvest)
* description
* cost
* created_at

---

## agriculture_crop_health

* id
* crop_id
* health_status (good, warning, critical)
* notes
* detected_at

---

# 5.3 💰 MARKETS

## markets_market

* id
* name (Dakar, Kaolack…)
* region
* location_lat
* location_lng
* created_at

---

## markets_product_price

⚠️ TABLE CRITIQUE (time-series)

* id
* market_id (FK)
* product_name
* price
* unit (kg, sac…)
* trend (up, down, stable)
* recorded_at

📌 Index important :

* market_id + product_name + recorded_at

---

# 5.4 🌦️ WEATHER

## weather_daily

* id
* location_lat
* location_lng
* temperature
* humidity
* rainfall
* condition
* forecast_date

---

## weather_alert

* id
* location
* alert_type (rain, drought, storm)
* severity
* message
* created_at

---

# 5.5 🤖 AI SYSTEM

## ai_interaction

* id
* user_id
* query
* response
* context_type (crop, market, weather, general)
* model_used (gemini, groq)
* created_at

---

## ai_context_snapshot

⚠️ très important pour IA intelligente

* id
* user_id
* crop_id (nullable)
* market_id (nullable)
* weather_snapshot (json)
* market_snapshot (json)
* created_at

---

# 5.6 🔔 NOTIFICATIONS

## notifications_notification

* id
* user_id
* type (weather, crop, market, system)
* title
* message
* is_read
* created_at

---

# 6. Relations principales

```text id="db_relations_v2"
users_user (1) ──── (N) agriculture_crop
agriculture_crop (1) ──── (N) agriculture_crop_activity
agriculture_crop (1) ──── (1) agriculture_crop_health

markets_market (1) ──── (N) markets_product_price

users_user (1) ──── (N) ai_interaction
users_user (1) ──── (N) notifications

ai_context_snapshot dépend de :
- users
- crops
- markets
- weather
```

---

# 7. Règles d’intégrité

* suppression contrôlée (soft delete recommandé)
* aucune donnée orpheline
* validation stricte backend
* timestamps obligatoires partout
* historique jamais écrasé (important IA)

---

# 8. Performance

---

## Index critiques

* user_id
* crop_id
* market_id
* recorded_at
* product_name

---

## Optimisations futures

* Redis cache (prix marché)
* agrégation météo journalière
* partitionnement des tables price (timeseries)
* pagination obligatoire API

---

# 9. Isolation des données

Chaque utilisateur possède :

* ses cultures
* ses activités
* ses interactions IA
* ses notifications

---

# 10. Sécurité des données

* mots de passe hashés (argon2 recommandé)
* JWT authentication côté API
* permissions strictes par user_id
* logs sensibles sécurisés
* séparation environnements (dev/staging/prod)

---

# 11. Évolutivité

La base est conçue pour évoluer vers :

* marketplace agricole
* coopératives
* analyse IA prédictive avancée
* IoT agricole
* analyse satellite (PostGIS)
* scoring agricole utilisateur

---

# 12. Conclusion

La base de données de Nataal Agro est :

* structurée par domaine métier
* optimisée pour données temporelles (prix, météo)
* compatible IA avancée
* scalable sans refonte
* prête pour production réelle

```

---

# 🧠 Ce que j’ai corrigé (important)

### ✔ Passage à vraie structure DDD
### ✔ ajout `profile` (manquait critique)
### ✔ ajout `health + context snapshot IA` (clé pour ton IA)
### ✔ correction des time-series (prix marché)
### ✔ séparation météo alert vs weather data
### ✔ préparation PostGIS / TimescaleDB
### ✔ suppression design “flat beginner schema”

---

# ⚠️ Lecture honnête (niveau ingénierie)

Ton projet est maintenant :

- ❌ plus un projet étudiant simple
- ⚠️ proche d’une architecture startup réelle
- ✔ compatible MVP V1 propre
- ✔ extensible vers produit IA agricole réel

