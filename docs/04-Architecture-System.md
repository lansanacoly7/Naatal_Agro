# Nataal Agro — System Architecture

| Informations | Valeur |
|--------------|---------|
| Projet | Nataal Agro |
| Document | System Architecture |
| Version | 1.0 |
| Statut | En cours |
| Dépend de | 03-UX-UI.md |
| Objectif | Définir l’architecture technique globale du système |

---

# 1. Vue d’ensemble du système

Nataal Agro est une architecture **client-serveur modulaire** composée de :

- 📱 Flutter (Mobile App)
- 💻 React (Web Dashboard - futur)
- ⚙️ Django REST API (Backend)
- 🗄️ PostgreSQL (Base de données)
- 🤖 IA (Gemini + Groq)
- 🔔 Firebase (Notifications)

---

# 2. Architecture globale

```text id="sys_arch_1"

        ┌──────────────────────┐
        │   Flutter Mobile     │
        └─────────┬────────────┘
                  │ REST API
                  ▼
        ┌──────────────────────┐
        │   Django Backend     │
        │  (REST Framework)    │
        └─────────┬────────────┘
                  │
     ┌────────────┼──────────────┐
     ▼            ▼              ▼
PostgreSQL   IA Services   Firebase FCM
3. Principes d’architecture
3.1 Modularité

Chaque domaine métier est indépendant :

users
agriculture
markets
weather
ai_assistant
notifications
3.2 Séparation des responsabilités
Flutter = UI + logique locale
Django = logique métier + sécurité
PostgreSQL = stockage
IA = intelligence externe
Firebase = push notifications
3.3 Scalabilité

Chaque module peut évoluer indépendamment sans casser les autres.

4. Communication système
4.1 Flutter → Backend

Communication via :

REST API (JSON)
Auth JWT
HTTPS sécurisé
Exemple :
GET /api/markets/prices
Authorization: Bearer <token>
4.2 Backend → Database
Django ORM
PostgreSQL
transactions sécurisées
4.3 Backend → IA

Deux moteurs :

Gemini
analyse agricole
recommandations
contexte long
Groq
réponses rapides
assistant instantané

Flux :

User request → Django → AI Service → Response → Flutter
4.4 Backend → Firebase

Utilisé pour :

alertes météo
notifications agricoles
rappels de culture
prix marché
5. Modules backend (Django)

Chaque module est indépendant :

5.1 users
authentification
profils
permissions
JWT
5.2 agriculture
cultures
produits
cycles agricoles
historique
5.3 markets
prix produits
évolution
comparaison régions
5.4 weather
météo locale
alertes
recommandations
5.5 ai_assistant
requêtes IA
génération conseils
gestion prompts
5.6 notifications
push alerts
scheduling
triggers système
6. Flux utilisateur principal

1. User ouvre app
2. Flutter appelle API /dashboard
3. Django agrège :
   - météo
   - marchés
   - alertes
4. Retour JSON
5. Flutter affiche UI

7. Gestion des données
7.1 PostgreSQL structure logique
Users
Crops
Markets
Prices
WeatherData
Notifications
AIInteractions
7.2 Isolation des données

Chaque utilisateur a :

ses cultures
ses données
ses préférences
8. Sécurité système
8.1 Authentification
JWT tokens
refresh tokens
expiration sécurisée
8.2 Protection API
rate limiting
validation requests
permissions par rôle
8.3 Données sensibles
chiffrement des données critiques
protection des tokens
logs sécurisés
9. Performance
9.1 Optimisations backend
cache (future Redis)
requêtes optimisées ORM
pagination API
9.2 Optimisations mobile
stockage local (offline mode)
cache Flutter
requêtes minimisées
10. Gestion des erreurs
standard API error format
logs centralisés
fallback côté mobile
11. Scalabilité

Le système est conçu pour évoluer vers :

marketplace agricole
coopératives
IA avancée
analyse satellite
IoT agricole
12. Conclusion

L’architecture de Nataal Agro est basée sur :

séparation stricte des modules
communication API sécurisée
intelligence centralisée côté backend
UI légère côté mobile
évolutivité complète

---

# 🧠 Ce qu’on vient de valider

✔ UX/UI défini  
✔ Architecture système définie  
✔ Flux de données clair  
✔ IA intégrée proprement  
✔ Backend structuré  

---

# 🚀 Prochaine étape

👉 `05-Database-Design.md`

Et là on va faire quelque chose de très important :

- modèle relationnel PostgreSQL
- tables exactes
- relations
- contraintes
- schéma propre (niveau production)