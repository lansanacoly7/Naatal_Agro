# 🗄️ Notes de Migration & Schéma de Base de Données — Naatal Agro

Ce document récapitule l'architecture de la base de données et l'ordonnancement des migrations Django.

## 1. Moteur de Base de Données
- **Développement local** : SQLite (`backend/db.sqlite3`) ou PostgreSQL local.
- **Production cible** : PostgreSQL 15+ avec support des UUIDs (`uuid-ossp`) et des champs JSON (`jsonb`).

## 2. Ordre de Dépendance des Migrations Django
Les applications Django doivent être migrées dans l'ordre de leurs dépendances relationnelles :

1. `users` : Modèle personnalisé `User` (hérite de `AbstractUser` avec identifiant `phone_number` / `username` et `UUIDField`).
2. `agriculture` : Modèles `Crop` (relié à `User`), `Activity` (relié à `Crop`), `PestReport` (relié à `User`).
3. `markets` : Modèles `Market`, `Price` (relié à `Market`), `Product`, `PreSaleOffer` (relié à `User`), `PreSaleReservation` (relié à `PreSaleOffer` et `User`).
4. `weather` : Modèle `WeatherData` (enregistrements horodatés par région).
5. `notifications` : Modèle `Notification` (relié à `User` pour les alertes ravageurs, météo et cours des marchés).
6. `inventory` : Modèle `StockItem` (relié à `User` avec suivi d'alerte et stockage IA).
7. `finances` : Modèles `Sale` (relié à `Crop`) et `Transaction` (dépenses / revenus de l'exploitation).
8. `ai_assistant` : Modèle `AIInteraction` (historique des requêtes et recommandations contextualisées).

## 3. Commandes Usuelles
```bash
# Vérification de l'état des migrations
python manage.py showmigrations

# Création de nouvelles migrations
python manage.py makemigrations

# Application des migrations
python manage.py migrate
```
