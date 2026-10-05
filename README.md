# 🌾 Naatal Agro — Plateforme Agricole Intelligente pour le Sénégal

> **Votre copilote agricole intelligent** : Aider les producteurs et acteurs des filières agricoles au Sénégal à prendre de meilleures décisions grâce aux données agricoles en temps réel, à la météo géolocalisée, aux cotations des marchés et à l'intelligence artificielle décisionnelle.

---

## 🚀 Fonctionnalités Principales (V1)

1. **Authentification Sécurisée** : Connexion par numéro de téléphone sénégalais (+221) et JWT, avec sélection du rôle (Agriculteur / Acheteur B2B).
2. **Tableau de Bord Contextuel** : Suivi des cultures actives, surfaces exploitées, météo locale et cours des marchés en temps réel.
3. **Gestion des Cultures & Parcelles** : Suivi des stades végétatifs (semis, croissance, récolte), journal d'activités et préventions des risques phytosanitaires.
4. **Cotations des Marchés & Marketplace B2B** : Suivi des prix dans les marchés régionaux (Castors, Tilène, Kaolack, Touba, Saint-Louis) et système de réservation de pré-ventes.
5. **Météo Agricole Prédictive** : Alertes climatiques et prévisions de précipitations.
6. **Naatal IA Décisionnelle** : 
   - Conseils culturaux adaptés aux terroirs sénégalais.
   - Diagnostic phytosanitaire par vision artificielle (Gemini).
   - Analyse de rentabilité et Text-to-SQL sécurisé (Groq).
7. **Profil d'Exploitant Dynamique** : Vue complète de l'exploitation, des cultures suivies et paramètres personnalisés.

---

## 🛠️ Stack Technique

- **Mobile** : Flutter 3.x, Riverpod (State Management), GoRouter (Navigation), flutter_map (Cartographie OSM).
- **Backend** : Python 3.12+, Django 5.x, Django REST Framework, SimpleJWT.
- **Base de Données** : PostgreSQL (Production) / SQLite (Développement local).
- **Intelligence Artificielle** : Groq (Llama-3.1-8b-instant) + Google Gemini (1.5-flash).
- **Notifications** : Firebase Cloud Messaging (FCM).

---

## 📂 Structure du Répertoire

```text
├── backend/            # API REST Django & applications modulaires
│   ├── apps/           # Domaines métier (users, agriculture, markets, weather, etc.)
│   └── core/           # Configuration globale (base, local, prod)
├── mobile/             # Application mobile Flutter (Clean Architecture, Feature-first)
│   ├── assets/         # Images, polices et pictogrammes officiels
│   └── lib/            # Cœur de l'application mobile
├── ai/                 # Prompts de référence et spécifications de l'IA
├── database/           # Schémas, scripts SQL et notes de migration
├── docs/               # Spécifications détaillées (00 à 13)
└── scripts/            # Scripts d'automatisation (setup, seed, deploy)
```

---

## ⚡ Démarrage Rapide

### 1. Prérequis
- Python 3.12+
- Flutter 3.24+

### 2. Lancement du Backend Django
```bash
cd backend
python -m venv venv
.\venv\Scripts\activate
pip install -r requirements.txt
python manage.py migrate
python seed.py
python manage.py runserver
```

### 3. Lancement de l'Application Mobile Flutter
```bash
cd mobile
flutter pub get
flutter run
```
