# 🌾 Naatal Agro — Plateforme Agricole Intelligente pour le Sénégal

> **Votre copilote agricole intelligent** : Aider les producteurs et acteurs des filières agricoles au Sénégal à prendre de meilleures décisions grâce aux données agricoles en temps réel, à la météo géolocalisée, aux cotations des marchés et à l'intelligence artificielle décisionnelle.

---

## 🚀 Fonctionnalités Principales (V1)

1. **Authentification Sécurisée** : Connexion par numéro de téléphone sénégalais (+221) et JWT avec stockage sécurisé dans le Keystore/Keychain.
2. **Tableau de Bord Contextuel** : Suivi des cultures actives, surfaces exploitées, météo locale et cours des marchés en temps réel.
3. **Gestion des Cultures & Parcelles** : Suivi des stades végétatifs (semis, croissance, récolte), journal d'activités et préventions des risques phytosanitaires.
4. **Cotations des Marchés Agricoles** : Suivi cartographique et comparatif des prix dans les marchés régionaux (Castors, Tilène, Kaolack, Touba, Saint-Louis).
5. **Météo Agricole Prédictive** : Alertes climatiques et prévisions de précipitations géolocalisées.
6. **Naatal IA Décisionnelle** : 
   - Conseils agronomiques contextualisés aux parcelles et terroirs sénégalais.
   - Diagnostic phytosanitaire par vision artificielle (Gemini).
   - Analyse décisionnelle sécurisée sans fuite de données inter-exploitations (Groq / Llama-3.1).
7. **Profil d'Exploitant Dynamique** : Vue complète de l'exploitation, des cultures suivies et paramètres personnalisés.

---

## 🛠️ Stack Technique

- **Mobile** : Flutter 3.x, Riverpod (State Management), GoRouter (Navigation), flutter_map (Cartographie OSM).
- **Backend** : Python 3.12+, Django 5.x, Django REST Framework, SimpleJWT.
- **Base de Données** : PostgreSQL (Production) / SQLite (Développement local).
- **Intelligence Artificielle** : Groq (Llama-3.1-8b-instant) + Google Gemini (modèle configurable via `GEMINI_MODEL`).
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
└── scripts/            # setup, seed, deploy, outils Postman et génération du rapport
```

---

## ⚡ Démarrage Rapide

### 1. Prérequis
- Python 3.12+
- Flutter 3.24+
- Node.js 20+ (uniquement pour le tableau de bord web)

### 2. Backend Django
```bash
cd backend
python -m venv venv
.\venv\Scripts\activate          # Linux/macOS : source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env              # puis renseigner SECRET_KEY et les clés API
python manage.py migrate
python seed.py                    # données de démonstration
python manage.py runserver
```
`manage.py` utilise `core.settings.local` (développement). `wsgi.py`/`asgi.py` utilisent
`core.settings.prod`, qui exige `SECRET_KEY`, `ALLOWED_HOSTS` et `CORS_ALLOWED_ORIGINS`.

### 3. Application mobile Flutter
```bash
cd mobile
flutter pub get
flutter run                                   # émulateur Android : API sur 10.0.2.2:8000
# Téléphone réel ou serveur distant :
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000/api
```

### 4. Tableau de bord web (démonstration)
```bash
cd web && npm ci && npm run dev
```

---

## ✅ Tests et qualité

```bash
cd backend && python manage.py test       # tests API (isolation des données, IA, finances...)
cd mobile  && flutter analyze && flutter test
cd web     && npm run build
```
La CI GitHub Actions (`.github/workflows/ci.yml`) exécute ces contrôles, ainsi que la vérification des
migrations et `check --deploy`, sur chaque push et pull request vers `main`, `develop` et `test`.

## 🔐 Sécurité

- JWT : accès 1 jour, refresh 7 jours avec rotation ; tokens stockés dans le stockage sécurisé du téléphone.
- Chaque ressource privée (cultures, finances, stock, notifications) est filtrée par utilisateur.
- L'assistant IA ne reçoit que le contexte de l'utilisateur connecté et n'exécute aucun SQL.
- Limitation de débit : 10 requêtes/min sur login et inscription, 30/heure sur l'assistant IA.
- Ne jamais commiter `.env` ; utiliser `backend/.env.example` comme modèle.

## 📌 Périmètre actuel

Marketplace B2B, rôle acheteur, paiements Mobile Money et notifications push côté téléphone ne sont **pas**
implémentés dans cette version (voir `docs/13-Roadmap.md`, phase 3). Le backend sait envoyer des push
Firebase, mais l'application mobile ne s'enregistre pas encore (pas de `firebase_messaging`).
