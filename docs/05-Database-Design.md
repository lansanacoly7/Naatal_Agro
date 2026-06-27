# Nataal Agro — Database Design (PostgreSQL)

| Informations | Valeur |
|--------------|---------|
| Projet | Nataal Agro |
| Document | Database Design |
| Version | 1.0 |
| Statut | En cours |
| Dépend de | 04-Architecture-System.md |
| Objectif | Définir le modèle de données relationnel |

---

# 1. Objectif de la base de données

La base de données de Nataal Agro doit :

- stocker les données agricoles des utilisateurs
- gérer les cultures et leur cycle de vie
- stocker les prix des marchés
- gérer les données météo
- alimenter l’IA
- assurer la sécurité et l’isolation des données

---

# 2. Choix technologique

- PostgreSQL (base principale)
- ORM Django (gestion des requêtes)
- Extensions futures :
  - PostGIS (géolocalisation)
  - Redis (cache)

---

# 3. Principes de conception

- normalisation des données
- séparation des responsabilités
- scalabilité
- performance
- intégrité référentielle
- isolation des utilisateurs

---

# 4. Modèle global (entités principales)

---

## 4.1 Users

### Table: users_user

- id (UUID)
- name
- phone
- password_hash
- location
- language
- created_at

---

## 4.2 Agriculture (Produits / Cultures)

### Table: agriculture_crop

- id (UUID)
- user_id (FK → users)
- name (ex: riz, tomate)
- type (céréale, maraîchage, etc.)
- planting_date
- expected_harvest_date
- status (active, harvested, lost)
- area_size
- location

---

## 4.3 Crop Activities (journal agricole)

### Table: agriculture_activity

- id
- crop_id (FK)
- type (arrosage, fertilisation, traitement)
- description
- date
- cost (optionnel)

---

## 4.4 Markets

### Table: markets_market

- id
- name (Dakar, Thiès…)
- location (GPS)
- region

---

## 4.5 Market Prices

### Table: markets_price

- id
- market_id (FK)
- product_name
- price
- trend (up, down, stable)
- date

---

## 4.6 Weather Data

### Table: weather_data

- id
- location
- temperature
- humidity
- rainfall
- forecast_date

---

## 4.7 AI Interactions

### Table: ai_interactions

- id
- user_id (FK)
- query
- response
- context_type (market, crop, general)
- created_at

---

## 4.8 Notifications

### Table: notifications

- id
- user_id (FK)
- type (weather, crop, market)
- message
- is_read
- created_at

---

# 5. Relations principales

```text id="db_relations"

users (1) ──── (N) crops
crops (1) ──── (N) activities
markets (1) ──── (N) prices
users (1) ──── (N) notifications
users (1) ──── (N) ai_interactions
6. Règles d’intégrité
suppression en cascade contrôlée
pas de données orphelines
validation des types côté backend
timestamps obligatoires
7. Isolation des données

Chaque utilisateur ne peut accéder qu’à :

ses cultures
ses interactions IA
ses notifications
8. Performance
Index recommandés :
user_id
crop_id
market_id
date fields
Optimisations futures :
caching Redis pour prix marchés
agrégation météo quotidienne
pagination systématique API
9. Évolutivité

La base est conçue pour évoluer vers :

coopératives agricoles
marketplace
analyse prédictive IA
IoT agricole
cartographie avancée (PostGIS)
10. Sécurité des données
mots de passe hashés (bcrypt/argon2)
JWT côté API
séparation stricte des utilisateurs
logs d’accès sensibles
11. Conclusion

La base de données de Nataal Agro est conçue pour :

être simple au départ
évoluer sans refonte
supporter des fonctionnalités IA avancées
gérer des données agricoles réelles à grande échelle

---

# 🧠 Ce que tu viens de construire

✔ Architecture système  
✔ UX/UI  
✔ Base de données complète  
✔ Backend structuré  
✔ IA intégrée conceptuellement  

👉 Là, ton projet commence à ressembler à un **système agricole industriel réel**, pas un projet étudiant classique.

---

# 🚀 Prochaine étape

👉 `06-Backend-API.md`

Et là on va définir :

- endpoints Django
- structure REST
- auth JWT
- flux Flutter ↔ backend
- IA endpoints
- marchés API
- météo API
