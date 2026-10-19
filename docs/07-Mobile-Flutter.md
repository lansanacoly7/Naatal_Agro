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

Design system centralisé dans `lib/core/theme/app_theme.dart` (classe `AppColors` + `AppTheme.lightTheme`).

**Vert principal `#1B5E20`** (`AppColors.primary`, vert forêt) : couleur des actions primaires (boutons,
onglet actif,AppBar, indicateurs). Tous les autres tons en dérivent :

| Jeton | Valeur | Usage |
|---|---|---|
| `primary` | `#1B5E20` | Vert principal — actions, accents, onglet sélectionné |
| `primaryLight` | `#4C8C4A` | Variante claire |
| `primaryDark` | `#0F4F31` | Variante sombre |
| `secondary` | `#007AFF` | Bleu secondaire (liens, compléments) |
| `background` | `#F2F4F1` | Fond général (gris très clair) |
| `surface` | `#FFFFFF` | Cartes |
| `textPrimary` / `textSecondary` | `#1C1C1E` / `#8E8E93` | Texte principal / secondaire |
| `error` / `warning` | `#FF3B30` / `#FF9500` | Alertes |
| `accentGold` / `accentEmerald` / `accentSky` | `#D97706` / `#059669` / `#0284C7` | Accents terroir (récoltes, météo) |

Dégradés signature : `primaryGradient` (`#0B3B1D → #1B5E20 → #15803D`), `weatherGradient`, `goldGradient`,
`aiGradient`. Typographie : Onest, police variable embarquée dans l'application (`assets/fonts/Onest.ttf`),
définie dans `mobile/lib/ui/typography.dart` (classe `T`). Material 3, transitions Cupertino homogènes.

Le design system réellement utilisé par l'application est celui de `mobile/lib/ui/` (un seul import
`package:.../ui/ui.dart`) articulé autour de la charte **« Images d'abord »** :
- **Philosophie d'usage** : Compréhension immédiate sans lecture pour les producteurs du Sénégal. Chaque fonction (vendre, récolter, stock, marchés, météo, cultures, finances, aide IA) est identifiée par une photo ou illustration claire, avec un libellé court (1 à 3 mots), de très grandes cibles tactiles (≥ 56 px partout), et un pré-remplissage maximal (peu de saisie manuelle).
- **Fond & Vert de marque** : Fond crémeux sahélien `#FBF7F0` (`NaatalColors.bg`), cartes blanches avec ombres douces et bordures fines, vert forêt `#1B5E20` unique (~20% max de l'écran, réservé aux actions décisives et marque).
- **Palette par domaine métier** :
  - Vente / Stock : Ambre / Doré `#D97706` (`c.accent`)
  - Cultures / Production : Émeraude `#059669`
  - Finances / Dépenses : Brique / Terre cuite `#C2410C` (`c.clay`)
  - Marchés / Météo : Bleu ardoise `#475569` (`c.slate`)
- **Composants clés** :
  - `PhotoTile` (`mobile/lib/ui/photo_tile.dart`) : tuile avec photo plein cadre (format paysage ou carré), dégradé sombre en bas pour garantir le contraste du texte, libellé court 1 à 3 mots, et badges d'état contextuels.
  - `BigActionButton` (`mobile/lib/ui/big_action_button.dart`) : très grand bouton tactile (hauteur ≥ 56 px à 80 px) avec photo d'action ou icône + libellé court.
  - `EmptyState` enrichi (`mobile/lib/ui/states.dart`) : écran d'état vide honnête avec photo d'ambiance locale (`ui_stock.jpg`, `ui_depenses.jpg`, `ui_premiere_culture.jpg`, etc.) et un bouton d'action primaire unique.
  - `Keypad` (`mobile/lib/ui/keypad.dart`) : pavé numérique tactile pour saisie rapide sans solliciter le clavier virtuel système.
  - `SuccessReveal` (`mobile/lib/ui/success_reveal.dart`) : confirmation visuelle animée plein écran avec grande coche et récapitulatif clair.
  - `MarketSheet` (`mobile/lib/screens/markets/market_sheet.dart`) : fiche marché contextuelle associant photo studio du produit, cours en FCFA/kg, variation calculée et prix de référence.
  - Cartes et listes : `AppCard`, `GroupedList`, `GroupedRow`, `Skeleton`, `ErrorState`, `PillButton`, `LargeTitleScaffold`, `PressScale`.
Tous les composants s'appuient strictement sur les jetons sémantiques de `tokens.dart` (`NaatalColors` via `context.c`, `Space`, `Radii`, `Motion`, `Hit`), sans couleur brute dans les écrans.

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

## Barre de navigation fixe (onglets)

La coque `MainShell` (`lib/screens/shell/main_shell.dart`) place une `NavigationBar` Material 3 en
`bottomNavigationBar` : elle reste **fixe en bas de l'écran**, au-dessus du contenu (le corps de chaque
écran est scrollé sous elle, jamais recouvert). 5 onglets, atteignables en une tape :

| Onglet | Route | Écran |
|---|---|---|
| 🏠 Accueil | `/` | `HomeScreen` (Quick Actions 6 tuiles photo, météo locale, résumé cultures, stock, marchés) |
| 🌾 Cultures | `/agriculture` | `CulturesScreen` (« Mon exploitation » cartes photo, filtres icônes + « Découvrir » grille 2 colonnes) |
| 💰 Marchés | `/markets` | `MarketsScreen` (carte interactive, en-tête studio, sélecteur photo, `MarketSheet` contextuelle) |
| 🤖 Naatal IA | `/ai` | `AssistantScreen` (héro photo, questions rapides studio, diagnostic phytosanitaire, réponses actionnables) |
| 👤 Profil | `/profile` | `ProfileScreen` (carte Aurora, avatar doré, exploitation, modales sécurité & export) |

Le libellé de l'onglet actif passe en vert principal `#1B5E20` (gris `textSecondary` sinon) ; la pastille
d'indicateur est le vert principal à 12 % d'opacité. La sélection se déduit de l'URL courante.

---

## Écrans clés (hors onglets)

Au-delà des 5 onglets, la navigation se fait par empilement (`context.push`) via GoRouter :

* **Auth** : `/onboarding`, `/login`, `/register`, `/welcome` (champs pré-remplissables, boutons ≥ 56 px)
* **Cultures** : 
  - `/agriculture/add` (`AddCropScreen`) : choix par grille de photos studio, cycle officiel pré-rempli, boutons − / +, bouton unique 56 px.
  - `/crop_detail` (`CropDetailScreen`) : 4 grands boutons tactiles photo (`Arroser`, `Engrais`, `Traiter`, `Récolter`) qui enregistrent en direct via l'API, journal d'activités réel, dates en français sans `intl`.
  - `/agriculture/culture` (`CultureFicheScreen`) : guide agronomique complet.
  - `/agriculture/guides` + `/agriculture/guides/:slug` : fiches agronomiques 100% sénégalaises.
* **Marchés & Vente** :
  - `/sell` (`SellScreen`) : vente rapide avec photos studio des 44 produits, pastilles rapides, clavier tactile et révélation `showSuccessReveal`.
  - `/stock` (alias `/inventory`) (`StockScreen`) : inventaire visuel avec photos studio, alertes de seuil, états vides illustrés `ui_stock.jpg`.
  - `/finances` (`FinancesScreen`) : synthèse entrées/sorties, détection automatique de culture, photos studio sur les flux, suggestions rapides de motifs, état vide illustré `ui_depenses.jpg`.
* **Exploitation & Informations** :
  - `/calendar` (`CalendarScreen`) : calendrier cultural.
  - `/notifications` (`NotificationsScreen`) : alertes de ravageurs et de seuils.
  - `/weather` (`WeatherScreen`) : prévisions météo agricoles détaillées.

---

## Règles :

* max 3 niveaux de navigation
* pas de navigation profonde cachée
* retour rapide dashboard
* garde d'authentification : hors session, toute route renvoie vers `/login` (ou `/onboarding` la 1re fois)

---

# 11. UI Principles

---

* Material 3 design
* cards modernes
* gros éléments interactifs
* design terrain (lisible en extérieur)
* vert principal `#1B5E20` dominant (actions, onglets,AppBar)

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
