# 📱 Nataal Agro — Mobile Application (Flutter)

| Informations | Valeur |
|--------------|---------|
| Projet | Nataal Agro |
| Document | Flutter Architecture |
| Version | 2.0 |
| Statut | Mise à jour |
| Dépend de | 06-Backend-API.md |
| Objectif | Définir une architecture Flutter scalable et maintenable |

---

# 1. Objectif de l’application mobile

L’application mobile Nataal Agro est le **point d’entrée principal du système agricole**.

Elle doit :

- fonctionner en conditions réseau faibles
- être ultra rapide et intuitive
- centraliser agriculture + marchés + IA
- rester extensible sans refonte
- minimiser la complexité utilisateur

---

# 2. Architecture Flutter (Clean + Feature-Based)

Flutter est structuré selon 3 couches :

```text id="flutter_layers_v2"
Presentation (UI)
Domain (logique métier)
Data (API + local storage)
````

---

# 3. Structure du projet

```text id="flutter_structure_v2"
lib/
│
├── core/
│   ├── config/
│   ├── network/
│   ├── theme/
│   ├── router/
│   └── constants/
│
├── features/
│   ├── auth/
│   ├── home/
│   ├── agriculture/
│   ├── markets/
│   ├── map/
│   ├── ai/
│   ├── profile/
│   └── notifications/
│
├── shared/
│   ├── widgets/
│   ├── models/
│   └── utils/
│
└── main.dart
```

---

# 4. Core layer (fondation système)

---

## 4.1 core/config

* configuration API
* environment (dev / prod)
* base URLs

---

## 4.2 core/network

* API client (Dio recommandé)
* interceptors JWT
* gestion erreurs globale
* retry system

---

## 4.3 core/theme

* design system global
* couleurs agricoles
* typography
* spacing system

---

## 4.4 core/router

* navigation centralisée
* routes nommées
* guard authentication

---

# 5. Feature-based architecture

Chaque feature est **indépendante et auto-suffisante**.

---

## 5.1 Auth feature

* login
* register
* session management
* refresh token

---

## 5.2 Home (Dashboard)

### Rôle :

> centre de décision quotidien

### Contenu :

* météo
* alertes
* recommandations IA
* résumé des cultures
* aperçu marché

---

## 5.3 Agriculture feature

* gestion des cultures
* ajout culture
* cycle agricole
* journal d’activités
* état santé cultures

---

## 5.4 Markets feature

* prix des produits
* comparaison marchés
* tendances
* recommandations de vente

---

## 5.5 Map feature

* carte interactive Sénégal
* marchés géolocalisés
* prix par zone
* distance utilisateur

---

## 5.6 AI feature

* chat IA (contextuel)
* recommandations agricoles
* analyse marché + météo
* assistant décisionnel

---

## 5.7 Profile feature

* profil utilisateur
* cultures suivies
* préférences
* langue (FR / Wolof)
* paramètres

---

## 5.8 Notifications feature

* alertes météo
* alertes culture
* alertes marché
* push Firebase

---

# 6. State Management

---

## Choix recommandé

👉 Riverpod (obligatoire pour scalabilité)

---

## Pourquoi :

* séparation claire UI / logique
* testable
* scalable
* adapté multi-modules

---

# 7. Data Layer (très important)

Chaque feature contient :

```text id="data_layer_v2"
repository/
datasource/
models/
```

---

## Exemple flow :

```text id="data_flow_v2"
UI → Controller → Repository → API Service → Django Backend → Response → UI
```

---

# 8. API Service Layer

Centralisation obligatoire :

* auth_service
* market_service
* agriculture_service
* ai_service
* weather_service

---

# 9. Offline Mode (critique pour Sénégal)

---

## Objectif :

L’application doit fonctionner même sans internet stable.

---

## Stratégie :

* cache local (Hive)
* stockage dernières données
* file d’attente requêtes (sync later)

---

## Données offline :

* cultures
* calendrier agricole
* derniers prix marchés
* conseils IA récents

---

# 10. Navigation system

---

## Bottom Navigation (fixe)

```text id="nav_flutter_v2"
🏠 Accueil
🌾 Produits
💰 Marchés
🗺️ Carte
🤖 IA
👤 Profil
```

---

## Règles :

* max 3 niveaux de navigation
* pas de navigation profonde cachée
* retour rapide dashboard

---

# 11. UI Principles

---

* Material 3 design
* cards modernes
* gros éléments interactifs
* design terrain (lisible en extérieur)
* couleurs agricoles (vert dominant)

---

# 12. Performance

---

* lazy loading
* pagination API
* optimisation images
* minimisation rebuilds
* séparation widgets intelligents / dumb widgets

---

# 13. Gestion des erreurs

---

* messages utilisateur simples
* fallback UI obligatoire
* retry automatique réseau
* offline fallback

---

# 14. Sécurité mobile

---

* stockage sécurisé (Secure Storage)
* tokens JWT encryptés
* aucune donnée sensible en clair
* expiration session gérée
* validation backend obligatoire

---

# 15. Scalabilité

---

Le système Flutter permet d’ajouter facilement :

* marketplace agricole
* chat communautaire
* extension web React sync
* IoT agricole
* analytics avancés

---

# 16. Conclusion

L’application Flutter Nataal Agro est :

> une interface mobile modulaire, rapide et intelligente connectée à un backend centralisé et évolutif.

Elle est conçue pour fonctionner dans des conditions réelles de terrain tout en restant scalable pour un produit agricole de niveau industriel.

```

---

# 🧠 Ce que j’ai corrigé (important)

### ✔ vraie architecture Clean (Presentation / Domain / Data)
### ✔ structure feature-ready production
### ✔ offline mode structuré (pas vague)
### ✔ API layer formalisé
### ✔ navigation stabilisée produit réel
### ✔ séparation correcte des responsabilités
### ✔ préparation extension React / IoT / marketplace

---
