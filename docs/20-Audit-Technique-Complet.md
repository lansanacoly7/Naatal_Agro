# 20 — AUDIT TECHNIQUE COMPLET DE L'APPLICATION NAATAL AGRO

| Informations | Valeur |
|---|---|
| **Projet** | Naatal Agro (Plateforme Agricole Intelligente pour le Sénégal) |
| **Document** | Audit Technique Exhaustif du Code & des Services |
| **Version** | 1.0 |
| **Date** | 13 Octobre 2026 |
| **Auteur** | Antigravity (Ingénieur Logiciel Senior & Tech Lead) |
| **Périmètre** | Mobile (Flutter), Web (React/Vite), Backend (Django REST), IA (Groq/Gemini), DevOps |

---

## 📋 1. Synthèse Exécutive

L'audit approfondi de la base de code révèle un écosystème à deux vitesses :

1. **Le Backend Django REST Framework** est particulièrement robuste, rigoureusement documenté, structuré en clean architecture modulaire et validé par une suite complète de **203 tests unitaires passants** (`OK`).
2. **Le module IA & Fiches Agronomiques** est opérationnel avec 19 fiches institutionnelles sénégalaises chargées et synchronisées, accompagnées de tests d'intégrité agronomique.
3. **L'application Mobile Flutter** compile et réussit ses 57 tests de non-régression, mais comporte encore des **poches importantes de code factice (mocks)**, des données écrites en dur, des boutons inactifs, ainsi qu'une contradiction technique bloquante sur le mode hors-ligne.
4. **L'application Web React** est actuellement un **prototype statique (mockup)** : une seule page avec des données codées en dur dans le JSX, des onglets inactifs et aucun appel API.

| Module | Statut Technique | Niveau de Fiabilité | Problèmes Majeurs Identifiés |
| :--- | :--- | :--- | :--- |
| **Mobile (Flutter)** | ⚠️ Fonctionnel avec Mocks résiduels | 65% | Mocks dans 4 écrans clés, contradiction offline/repositories, modules Météo/Map incomplets. |
| **Web (React)** | ❌ Prototype non connecté | 15% | Page unique, onglets inactifs, zéro appel API (`axios` non utilisé), zéro authentification. |
| **Backend (Django)** | ✅ Robuste & Validé (203 tests) | 90% | Absence de passerelle SMS pour l'OTP et la réinitialisation de mot de passe. |
| **IA & Fiches Agro** | ✅ Solide & Intégré | 85% | RAG agronomique opérationnel avec fallback Groq/Gemini, dépendance aux clés API externes. |

---

## 🔴 2. Audit de l'Application Mobile (Flutter)

### 2.1. Données factices et Mockups résiduels (Violation de la Règle n°17)

Bien que de nombreux écrans aient été assainis lors des livraisons précédentes (profil, finances, fiches agronomiques), plusieurs écrans continuent d'utiliser des listes locales en mémoire et des simulations mathématiques :

#### A. Calendrier Agricole (`mobile/lib/features/dashboard/presentation/screens/calendar_screen.dart`)
* **Localisation :** Lignes 71 à 150 (`final List<CropLifecycle> _mockCrops = [...]`).
* **Constat :** L'écran n'appelle aucun endpoint API. Il repose entièrement sur un modèle local factice avec des parcelles inventées (*"Parcelle Nord"*, *"Champ Principal"*), de fausses dates de semis, et de faux ajustements météo (*"Une pluie importante est prévue le 18 juin"*).
* **Conséquence :** L'agriculteur ne voit jamais ses vraies cultures ni ses vraies activités planifiées.
* **Correction requise :** Raccorder l'écran au provider d'activités et de cultures (`/api/agriculture/activities/` et `/api/agriculture/crops/`).

#### B. Comparateur de Marchés (`mobile/lib/features/markets/presentation/screens/market_comparison_screen.dart`)
* **Localisation :** Lignes 50 à 56 :
  ```dart
  final base = product.currentPrice > 0 ? product.currentPrice : 450.0;
  allMarkets['Sandaga'] = base;
  allMarkets['Tilène'] = base - 15;
  allMarkets['Castors'] = base + 20;
  allMarkets['Rufisque'] = base - 25;
  allMarkets['Thiaroye'] = base - 10;
  ```
* **Constat :** Les prix des marchés de Dakar ne proviennent pas de la base de données : ils sont calculés par une formule arbitraire (`base - 15`, `base + 20`, etc.).
* **Correction requise :** Interroger l'endpoint réel `GET /api/markets/prices/?product_name=...` pour obtenir les vraies cotations relevées sur chaque marché.

#### C. Base Produits Statique (`mobile/lib/features/markets/data/mock_product_database.dart`)
* **Localisation :** Fichier complet et son utilisation dans `product_detail_screen.dart` et `market_comparison_screen.dart`.
* **Constat :** Présence d'un catalogue figé de 4 produits avec génération artificielle de texte et de notes génériques (`_generateGenericProduct`) dès qu'un produit sort de la liste.
* **Correction requise :** Utiliser les données du modèle Django `Product` via `GET /api/markets/products/`.

#### D. Écran d'Accueil (`mobile/lib/features/dashboard/presentation/screens/dashboard_screen.dart`)
* **Ligne 912 :** Affichage d'une alerte en dur agronomiquement aberrante au Sénégal : *"Risque de gel cette nuit sur la parcelle Nord"*.
* **Lignes 1018-1048 (`_buildTodayTasks`) :** Trois tâches quotidiennes codées en dur sans lien avec le calendrier de l'exploitant.
* **Lignes 1166-1196 (`_buildAiTipsScroll`) :** Carrousel de 4 conseils IA figés dans le code source au lieu d'utiliser les suggestions réelles de l'IA.
* **Ligne 845 :** Ratio de stock calculé artificiellement : `final double fillPercentage = (item.quantity / 1000).clamp(0.1, 1.0); // Dummy logic`.

#### E. Détail d'une Culture (`mobile/lib/features/agriculture/presentation/screens/crop_detail_screen.dart`)
* **Lignes 306-309 (`_buildTasksSection`) :** Tâches en dur (*Irrigation approfondie*, *Apport NPK*, *Sarclage*) modifiées uniquement dans un `Set<String>` local en mémoire sans persistance.
* **Lignes 362-396 (`_buildRisksSection`) :** *"Risque de Mildiou élevé"* affiché statiquement pour toutes les cultures sans exception.

#### F. Écran des Notifications (`mobile/lib/features/profile/presentation/screens/notifications_screen.dart`)
* **Lignes 9-28 :** `final List<Map<String, dynamic>> notifications = [...]` est une liste statique en dur.
* Cet écran est un doublon inachevé : le projet possède déjà un panneau complet connecté à l'API (`mobile/lib/core/widgets/notifications_sheet.dart`).

---

### 2.2. Contradiction Technique Bloquante : Cache Hors-Ligne vs Repositories

* **Fichiers :** [`api_client.dart`](file:///c:/Users/pathe/Desktop/Naatal_Agro/mobile/lib/core/network/api_client.dart#L65-L77) et [`agriculture_provider.dart`](file:///c:/Users/pathe/Desktop/Naatal_Agro/mobile/lib/features/agriculture/data/agriculture_provider.dart#L83-L85).
* **Mécanisme en conflit :**
  1. En mode hors-ligne, quand une requête de mutation (`POST`, `PUT`, `DELETE`) échoue pour cause réseau, l'intercepteur `ApiClient` intercepte l'erreur, met l'action en file dans `SyncService` et résout la requête avec un code HTTP **`202 Accepted`** (`{'message': 'Action sauvegardée (Offline)', 'offline': true}`).
  2. Cependant, dans `AgricultureRepository` :
     ```dart
     // addCrop (ligne 83)
     if (response.statusCode != 201) {
       throw Exception('Erreur lors de l\'ajout de la culture');
     }
     // updateCrop (ligne 94)
     if (response.statusCode != 200) {
       throw Exception('Erreur lors de la mise à jour de la culture');
     }
     // deleteCrop (ligne 105)
     if (response.statusCode != 204) {
       throw Exception('Erreur lors de la suppression de la culture');
     }
     ```
* **Impact :** Dès qu'un utilisateur hors-ligne ajoute, modifie ou supprime une culture, l'application lève une exception rouge à l'écran, bien que l'action soit correctement mise en file dans le `SyncService`.
* **Correction :** Mettre à jour les méthodes du repository pour accepter également le statut `202` :
  ```dart
  if (response.statusCode != 201 && response.statusCode != 202) { ... }
  ```

---

### 2.3. Boutons Inactifs (Dead Buttons) et Fonctionnalités Factices

| Fichier | Élément | Comportement Actuel | Comportement Attendu |
| :--- | :--- | :--- | :--- |
| `notifications_screen.dart:52` | Tout marquer comme lu | `onPressed: () {}` (vide) | Requête API vers `/api/notifications/mark-all-read/` ou boucle sur les IDs non lus. |
| `dashboard_screen.dart:205` | Recherche dans le header | SnackBar *"Bientôt disponible"* | Filtrer les parcelles ou rediriger vers un écran de recherche. |
| `dashboard_screen.dart:635` | Bouton "Terminer" activité | SnackBar local sans appel API | Mettre à jour l'activité (`is_completed`) dans l'API Django. |
| `market_detail_screen.dart:35` | Partage du marché | SnackBar *"Lien copié"* factice | Copie réelle dans le presse-papiers (`Clipboard.setData`). |
| `edit_profile_screen.dart:86` | Photo de profil | Choix d'image actif mais photo ignorée au `saveProfile()` | Upload multipart vers l'endpoint de profil utilisateur. |
| `login_screen.dart:109` | Mot de passe oublié | SnackBar *"Instructions SMS envoyées"* sans appel serveur | Intégration d'un vrai flux de réinitialisation. |
| `register_screen.dart:107` | Code OTP | N'importe quel code à 4 chiffres valide l'étape | Vérification d'un code OTP généré côté serveur. |

---

### 2.4. Modules V1 Spécifiés mais Absents du Mobile

1. **Module Météo Agricole complet (Priorité V1 n°5) :**
   * L'endpoint backend `/api/weather/` et la constante `AppConstants.weatherEndpoint` existent.
   * **Manque :** Aucun écran Météo dédié, aucun provider Riverpod pour les prévisions à 7 jours, aucune route `/weather` dans `app_router.dart`.
2. **Module Cartographie interactive (Priorité V1 n°6) :**
   * Les packages `flutter_map` et `latlong2` sont installés dans le `pubspec.yaml`.
   * **Manque :** Aucune carte interactive pour visualiser les marchés locaux, les exploitations ou les foyers de ravageurs signalés.

---

## 🔴 3. Audit du Front-End Web (React)

L'application web ([`web/src/App.tsx`](file:///c:/Users/pathe/Desktop/Naatal_Agro/web/src/App.tsx)) est un **prototype statique non relié au backend** :

1. **Architecture non conforme :** Le document [`docs/08-Web-React.md`](file:///c:/Users/pathe/Desktop/Naatal_Agro/docs/08-Web-React.md) prévoyait une Clean Architecture modulaire (`core/`, `domain/`, `features/`, `services/`, `store/`). Le code source ne contient actuellement que 3 fichiers dans `web/src/` (`App.tsx`, `index.css`, `main.tsx`).
2. **Onglets inactifs :** Cliquer sur *Marchés & Prix*, *Exploitations*, *Météo Agricole* ou *Naatal IA* dans la barre latérale met à jour la variable d'état `activeTab`, mais le rendu DOM reste strictement le même tableau de bord figé.
3. **Zéro appel API :** `axios` est importé ligne 3 (`import axios from 'axios';`) mais n'est **jamais utilisé**. Tous les chiffres (*1 248 exploitants*, *3 420 Ha*, *856 requêtes IA*) sont écrits en dur dans le JSX.
4. **Cotations figées :** La table des marchés utilise une date statique `"2026-07-19"`.
5. **Absence d'authentification :** Aucun formulaire de connexion, aucun token JWT, aucun mécanisme de session ou de protection de route.

---

## 🟡 4. Audit du Back-End (Django REST Framework)

Le backend est le composant le plus fiable du projet (203 tests exécutés avec succès). Les points d'amélioration concernent l'infrastructure externe :

1. **Notifications Push Firebase ([`firebase_service.py`](file:///c:/Users/pathe/Desktop/Naatal_Agro/backend/apps/notifications/firebase_service.py)) :**
   * Si la variable d'environnement `FIREBASE_CREDENTIALS_PATH` est absente, le service désactive silencieusement les notifications push.
2. **Dépendance aux Clés API Externes :**
   * **Météo :** En l'absence de `API_KEY_OPENWEATHER`, la fonction `fetch_weather_for_location` renvoie `None` et retombe sur la base locale. Si la base est vierge, l'endpoint renvoie une liste vide.
   * **IA :** Si `API_KEY_GROQ` et `API_KEY_GEMINI` ne sont pas renseignées, l'assistant renvoie une erreur au lieu d'un message d'aide explicite.
3. **Absence de passerelle SMS :**
   * Aucun endpoint backend n'existe pour l'émission ou le contrôle de codes OTP par SMS (expliquant pourquoi le mobile simule cette étape).

---

## 🛠️ 5. Plan d'Action Recommandé (Roadmap de Remédiation)

### Phase 1 : Assainissement Mobile (Priorité Immédiate)
- [ ] Raccorder `CalendarScreen` aux modèles réels `Crop` et `Activity`.
- [ ] Raccorder `MarketComparisonScreen` aux vrais prix de l'endpoint `/api/markets/prices/`.
- [ ] Supprimer `MockProductDatabase` et brancher les fiches produits sur `/api/markets/products/`.
- [ ] Nettoyer `DashboardScreen` : supprimer l'alerte de gel, brancher les vraies alertes non lues et les vraies tâches du jour.
- [ ] Corriger `AgricultureRepository` pour accepter le code HTTP `202 Accepted` en mode hors-ligne.
- [ ] Remplacer ou rediriger `notifications_screen.dart` vers `notifications_sheet.dart`.

### Phase 2 : Modules V1 Manquants
- [ ] Créer un écran dédié `WeatherScreen` affichant la météo détaillée par région (`GET /api/weather/`).
- [ ] Créer un écran cartographique `MapScreen` exploitant `flutter_map` pour afficher les marchés du Sénégal.

### Phase 3 : Mise à Niveau du Front-End Web React
- [ ] Mettre en place le routeur React (`react-router-dom`) avec pages séparées : Dashboard, Marchés, Exploitations, Météo.
- [ ] Configurer l'instance Axios centralisée avec intercepteur JWT.
- [ ] Créer une page de connexion Administrateur reliée à `/api/users/auth/login/`.
- [ ] Remplacer les statistiques en dur par les données réelles de `/api/dashboard/` et `/api/markets/`.
