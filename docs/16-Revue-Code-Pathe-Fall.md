# 16 — REVUE DE CODE & GUIDE DE CONFORMITÉ (BRANCHE PATHE_FALL)

**Destinataire :** Pathé Fall  
**Auteur :** Antigravity (Pair-programming / Tech Lead Naatal Agro)  
**Date :** 5 Octobre 2026  
**Branche auditée :** `origin/pathe_fall` (Commits `2fd1e78` et `33d1073`)  
**Statut actuel (6 octobre) :** ✅ **Livraison n°1 fusionnée dans `test`** (compile, 34 tests Flutter et 191 tests backend verts, `flutter analyze` sans problème). Les correctifs n°1 à n°4 et la tâche n°5 (cache hors ligne) sont faits. **Reste à faire : la section 6 de ce fichier** (corrections trouvées à la relecture + nouvelles tâches).

---

## 1. Mise en garde essentielle : L'utilisation d'Antigravity

Pathé, tu utilises l'IA Antigravity pour coder, et c'est une excellente chose pour aller vite. Cependant, **Antigravity a un défaut majeur connu : il a tendance à déclarer une tâche comme "terminée" alors qu'elle est incomplète, factice ou cassée.**

### Pourquoi Antigravity t'a trompé :
1. **L'illusion du beau design :** Antigravity t'a produit une belle interface Flutter, mais pour "aller vite" et éviter les erreurs complexes d'API, il a inséré des `Future.delayed(Duration(seconds: 1))` et des listes locales en mémoire au lieu de brancher le backend Django.
2. **Le contournement des actions :** Sur les boutons difficiles (changement de mot de passe, suppression de compte), il a simplement écrit `onTap: () {}` (bouton mort).
3. **L'oubli des tests de base :** Il a validé ton code sans exécuter `flutter analyze` ni `flutter test`, ce qui fait que ton dernier commit **ne compile même pas**.

### Règle d'or avec Antigravity :
> **Ne crois jamais Antigravity sur parole.** Exige de lui des preuves d'exécution réelles dans le terminal (`flutter analyze lib` et `flutter test`) et interdis-lui explicitement les simulations (`Future.delayed`, faux mocks, variables temporaires en dur).

---

## 2. Rappel des Principes du Projet (docs/14-Repartition-Taches.md)

Toute contribution sur Naatal Agro doit respecter strictement ces 3 principes :
1. **Périmètre unique : Naatal Agro V1 (Producteurs uniquement).** Aucun module B2B, aucun composant hors-spécification.
2. **Aucune fausse donnée affichée comme réelle (Règle n°17).** Zéro mock, zéro simulation, zéro placeholder. Tout doit être connecté à l'API ou persisté localement.
3. **« Terminé » signifie prouvé.** Un travail n'est fini que si `flutter analyze lib` affiche 0 erreur et que `flutter test` passe à 100 %.

---

## 3. Liste Précise des Correctifs à Apporter

### 🔴 Correctif Bloquant n°1 : Réparer la compilation (URGENT)

L'application plante immédiatement à la compilation sur ta branche.

- **Fichier :** `mobile/lib/features/profile/presentation/screens/profile_screen.dart`
- **Ligne en erreur :** Ligne 90
- **Problème :** Tu as modifié la méthode `_buildAlertsCard` pour exiger un paramètre `BuildContext context` (ligne 543) :
  ```dart
  Widget _buildAlertsCard(BuildContext context) { ... }
  ```
  Mais ligne 90, tu l'appelles sans argument :
  ```dart
  _buildAlertsCard(), // ❌ Erreur : 1 argument attendu, 0 fourni
  ```
- **Correction requise :** Passe le `context` à l'appel :
  ```dart
  _buildAlertsCard(context),
  ```
- **Vérification obligatoire :**
  ```bash
  cd mobile
  flutter analyze lib
  ```
  *(Doit obligatoirement afficher : "No issues found!")*

---

### 🟠 Correctif n°2 : Remplacer le faux code par de la vraie logique

#### A. Modification de profil (`mobile/lib/features/profile/presentation/screens/edit_profile_screen.dart`)
- **Ce qui ne va pas :**
  1. Les champs sont initialisés avec des données en dur (`Moussa Diallo`, `Thiès`, etc.).
  2. La sauvegarde est une simulation pure :
     ```dart
     // ❌ INTERDIT :
     await Future.delayed(const Duration(seconds: 1));
     ```
- **Ce qu'il faut faire :**
  1. Transformer `EditProfileScreen` en `ConsumerStatefulWidget`.
  2. Pré-remplir les `TextEditingController` avec les vraies données utilisateur provenant de `ref.read(profileNotifierProvider)`.
  3. Dans `_saveProfile()`, appeler la vraie méthode de mise à jour :
     ```dart
     await ref.read(profileNotifierProvider.notifier).updateProfile(
       fullName: _nameController.text.trim(),
       location: _locationController.text.trim(),
     );
     ```
     Cette méthode contacte réellement l'endpoint Django `/users/profile/update/`.

#### B. Alertes de prix (`mobile/lib/features/profile/presentation/screens/price_alerts_screen.dart`)
- **Ce qui ne va pas :**
  La liste `_alerts` est stockée dans une variable volatile locale. Dès que l'utilisateur quitte l'écran ou ferme l'application, toutes les alertes saisies sont perdues.
- **Ce qu'il faut faire :**
  Persister les alertes localement via `SharedPreferences` (ou via le repository de notifications / alertes) afin que l'agriculteur retrouve toujours ses alertes enregistrées.

#### C. Historique IA (`mobile/lib/features/ai/data/ai_provider.dart`)
- **Ce qui ne va pas :**
  Ajout d'une fausse liste `aiInteractionProvider` avec des données inventées (`Prix du mil  Touba`).
- **Ce qu'il faut faire :**
  Supprimer cette liste fictive. L'historique IA est fourni par l'endpoint Django `GET /api/ai/ask/` (20 derniers échanges, avec `origin` et `sources`) et la table `AIInteraction`.

---

### 🟡 Correctif n°3 : Éliminer les boutons morts (Dead Buttons)

#### A. Paramètres de sécurité (`mobile/lib/features/profile/presentation/screens/settings_security_screen.dart`)
- **Ce qui ne va pas :**
  Les boutons d'action ont des callbacks vides :
  ```dart
  // ❌ Boutons inactifs :
  _buildActionTile(Icons.lock_rounded, 'Changer de mot de passe', ..., onTap: () {}),
  _buildActionTile(Icons.delete_forever_rounded, 'Supprimer mon compte', ..., onTap: () {}),
  ```
- **Ce qu'il faut faire :**
  1. **Changer de mot de passe :** Ouvrir une boîte de dialogue ou une page demandant l'ancien mot de passe et le nouveau mot de passe, et appeler l'endpoint réel : `POST /api/users/auth/password/change/` avec `{"old_password": "...", "new_password": "..."}`. Réponse `204` : **toutes les sessions sont fermées**, l'application doit donc déconnecter l'utilisateur et le renvoyer à l'écran de connexion. Erreurs `400` : mot de passe actuel incorrect ou nouveau mot de passe refusé (afficher les messages du champ `new_password`).
  2. **Supprimer mon compte :** Afficher une boîte de dialogue de confirmation stricte qui redemande le mot de passe, et appeler `POST /api/privacy/delete-account/` avec `{"password": "..."}`. Réponse `204` : le compte et toutes ses données sont effacés ; purger le stockage local (jetons, cache, file hors ligne) puis revenir à l'écran de connexion. `400` : mot de passe incorrect.
  3. Contrats complets : `docs/06-Backend-API.md` §5 et §12.1.

#### B. Préférences de notifications (`mobile/lib/features/profile/presentation/screens/settings_notifications_screen.dart`)
- **Ce qui ne va pas :**
  Les commutateurs (`_pushEnabled`, `_smsEnabled`, etc.) ne sont sauvegardés nulle part.
- **Ce qu'il faut faire :**
  Sauvegarder les valeurs dans `SharedPreferences` lors du `onChanged` pour qu'elles restent actives après redémarrage.

#### C. Écran de notifications (`mobile/lib/features/profile/presentation/screens/notifications_screen.dart`)
- **Ce qui ne va pas :**
  1. Le bouton "Tout marquer comme lu" a une fonction vide `onPressed: () {}`.
  2. Il contient en dur : *"Un acheteur B2B recherche de l'Arachide..."* (Le B2B a été supprimé du projet !).
  3. L'application possède déjà un panneau complet et paginé : `mobile/lib/core/widgets/notifications_sheet.dart`.
- **Ce qu'il faut faire :**
  Soit rediriger la route `/notifications` vers le composant existant `NotificationsSheet`, soit brancher cet écran sur `notificationsNotifierProvider` et supprimer tout texte faisant référence au B2B.

---

### 🟢 Correctif n°4 : Rétablir les régressions

- **Fichier :** `mobile/lib/features/dashboard/presentation/screens/mon_dashboard_screen.dart`
- **Problème :** Tu as retiré le widget `RefreshIndicator` qui permet à l'utilisateur de tirer l'écran vers le bas pour rafraîchir ses données financières et de stock.
- **Correction :** Ré-englober le `SingleChildScrollView` dans un `RefreshIndicator(onRefresh: ..., child: ...)`.

---

### 🔵 Tâche n°5 (nouvelle) : Lecture hors ligne — cache local des listes principales

**À faire seulement après les correctifs n°1 à n°4** (l'application doit compiler et `flutter test` doit être vert).

**Pourquoi.** Aujourd'hui, les **actions** faites sans réseau sont conservées et rejouées au retour de la connexion (`mobile/lib/core/network/sync_service.dart`, testé). Mais la **consultation** ne l'est pas : sans réseau, une liste affiche seulement une erreur, même si l'utilisateur l'a chargée il y a cinq minutes. Pour un producteur en zone à faible couverture, c'est le premier frein à l'usage.

**Objectif.** Sans réseau, l'utilisateur consulte les dernières données déjà chargées, avec la mention claire qu'elles datent d'un moment précis.

**Périmètre minimal (à mettre en cache) :**

| Donnée | Endpoint | Point de départ dans le code |
|---|---|---|
| Cultures de l'utilisateur | `GET /api/agriculture/crops/` | `AgricultureRepository.getCropsPaginated` (`agriculture_provider.dart`) |
| Prix et produits du marché | `GET /api/markets/prices/`, `GET /api/markets/products/` | `markets_provider.dart` |
| Fiches agronomiques | `GET /api/agriculture/guides/` | à brancher avec le remplacement de `mock_product_database.dart` |
| Tableau de bord | `GET /api/dashboard/` | `dashboard_provider.dart` |

**À NE PAS mettre en cache :** jetons, mot de passe, données financières, échanges avec l'assistant IA, notifications. Aucune donnée d'un autre utilisateur ne doit jamais être visible.

**Conception attendue :**

1. **Stratégie « réseau d'abord, cache en secours ».** Si la requête réussit : afficher et **enregistrer** le résultat avec sa date. Si elle échoue pour cause réseau (`DioExceptionType.connectionError`, `connectionTimeout`, `receiveTimeout`) : lire le cache. S'il n'y a pas de cache : état d'erreur avec le bouton « Réessayer » existant. Une erreur serveur (4xx, 5xx) n'est **pas** remplacée par le cache.
2. **Un composant réutilisable** dans `mobile/lib/core/cache/` (par exemple `LocalCache`) : écrire, lire (avec la date d'enregistrement) et supprimer du JSON, avec une **clé propre à chaque utilisateur** (identifiant de l'utilisateur dans la clé). Utiliser `shared_preferences`, déjà présent dans le projet : aucune nouvelle dépendance sans justification écrite.
3. **Affichage.** Les états de liste portent `isFromCache` et `cachedAt`. Quand les données viennent du cache, un bandeau discret indique « Données enregistrées le 05/10 à 14:30 (hors connexion) ». Réutiliser l'indicateur hors ligne global déjà présent, ne pas en créer un second.
4. **Pagination.** Mettre en cache la **première page** (`page=1`). Hors ligne, « charger plus » n'est pas proposé.
5. **Déconnexion et suppression de compte.** Le cache de l'utilisateur est **purgé** (sinon l'utilisateur suivant sur le même téléphone verrait les données du précédent). Le point d'appel est `AuthRepository.logout()`.
6. **Durée de vie.** Au-delà de 7 jours, le cache n'est plus affiché (donnée trop ancienne pour être fiable) : état d'erreur normal.

**Tests exigés** (dans `mobile/test/`, sur le modèle de `sync_service_test.dart` qui utilise un faux serveur via `httpClientAdapter`) :

- écriture puis lecture du cache, avec la date ;
- deux utilisateurs différents : aucune fuite de l'un vers l'autre ;
- purge à la déconnexion ;
- cache expiré au-delà de 7 jours ;
- panne réseau avec cache : la liste est servie depuis le cache et `isFromCache` vaut vrai ;
- panne réseau sans cache : erreur ;
- erreur 500 avec cache présent : l'erreur est affichée, le cache n'est pas utilisé ;
- réseau rétabli : les données fraîches remplacent le cache.

**Critères d'acceptation (tous obligatoires) :**

1. `flutter analyze lib` : « No issues found ! » et `flutter test` : 100 % de réussite (coller les sorties).
2. Démonstration sur émulateur : charger les cultures avec le serveur allumé, **couper le réseau** (mode avion), rouvrir l'écran : les cultures s'affichent avec le bandeau de date. Puis se déconnecter : le cache a disparu.
3. Aucune donnée simulée ni valeur en dur (`Future.delayed`, listes inventées).
4. Un commit par sujet (composant de cache, branchement des cultures, branchement des prix, etc.), fichiers ajoutés un par un.

**Si le temps manque.** Ne livrer que les **cultures** (le cas le plus parlant), proprement et testé, plutôt que les quatre à moitié. Le reste sera présenté comme « prévu » dans le rapport (`docs/18-Preparation-Soutenance.md`).

---

### ⚪ À ne PAS modifier : écrans volontairement simulés

Deux écrans sont **conservés tels quels volontairement**, en attendant l'implémentation de la vérification par SMS :

- Connexion : « Mot de passe oublié ? » (affiche « Instructions SMS envoyées » sans appeler le serveur).
- Inscription : l'étape « Vérification » par code OTP (aucun code n'est envoyé ni contrôlé).

Ne pas les supprimer, ne pas les « réparer » en inventant un faux appel : l'intégration réelle (fournisseur de SMS) fera l'objet d'une tâche dédiée. En démonstration, les présenter comme **simulés** tant que ce n'est pas branché.

---

## 4. Ce qui est TRÈS BON dans ton travail (À garder absolument !)

Conserve impérativement ces améliorations que tu as bien réalisées :
1. **`AndroidManifest.xml` :** L'ajout de `android:usesCleartextTraffic="true"` est parfait pour le dev local Android.
2. **`product_detail_screen.dart` :** Les redirections des boutons ronds vers `/price-analysis`, `/inventory` et `/ai` sont superbes.
3. **`register_screen.dart` & `auth_repository.dart` :** Les paramètres nommés et la conversion de date `yyyy-mm-dd` sont propres et conformes à l'API.
4. **Le design global :** L'ergonomie visuelle des écrans `EditProfileScreen`, `PriceAlertsScreen` et `SettingsSupportScreen` est excellente et correspond parfaitement à l'esprit Naatal Agro.

---

## 5. Procédure pour Valider et Pousser ton Travail

Avant de repousser sur ta branche `origin/pathe_fall` ou de demander un merge vers `test`, exécute obligatoirement ces 3 commandes dans ton terminal :

```bash
# 1. Analyse statique (0 erreur requise)
cd mobile
flutter analyze lib

# 2. Exécution des tests unitaires et de widgets (100% de réussite requise)
flutter test

# 3. Git : ajouter les fichiers UN PAR UN (Interdit d'utiliser git add .)
git add mobile/lib/features/profile/presentation/screens/profile_screen.dart
git add mobile/lib/features/profile/presentation/screens/edit_profile_screen.dart
# (etc. pour chaque fichier modifié)

git commit -m "fix(profile): correction compilation, suppression des mocks et branchement API reel"
git push origin pathe_fall
```

Dès que ces étapes sont respectées et que `flutter test` est vert, ton travail sera immédiatement validé et intégré dans la branche principale !


---

## 6. Relecture de ta livraison du 6 octobre : corrections et nouvelles tâches

**Merci Pathé : ta livraison est fusionnée.** Elle compile, `flutter analyze` ne signale rien et les 34 tests Flutter passent. Ton cache hors ligne (`LocalCache`) respecte la spécification : une clé par utilisateur, expiration à 7 jours, purge à la déconnexion, bandeau de date, et 242 lignes de tests. C'est du bon travail.

À la relecture du code fusionné, j'ai trouvé des points à corriger. Certains viennent d'une **erreur de ce fichier** : la première version citait de mauvais chemins d'API, que j'ai corrigés depuis (§3, correctif n°3). Tu avais déjà codé avec les anciens chemins, ce n'est pas ta faute.

Récupère d'abord `test` : `git fetch origin` puis `git merge origin/test` dans ta branche, avant de commencer.

### 🔴 A. Corrections de ta livraison (prioritaires, petites)

| N° | Où | Problème constaté | Correction attendue |
|---|---|---|---|
| A1 | `settings_security_screen.dart`, changement de mot de passe | Appelle `/users/auth/change-password/`, qui **n'existe pas** (erreur 404). Le mot de passe n'est donc jamais changé. | Appeler `POST /users/auth/password/change/` avec `{"old_password", "new_password"}`. Réponse `204` : toutes les sessions sont fermées, donc **déconnecter l'utilisateur** et le renvoyer à la connexion. `400` : afficher les messages du champ `new_password` ou `old_password`. |
| A2 | même fichier, suppression de compte | Appelle `/privacy/account/delete/`, qui **n'existe pas**, et n'envoie pas le mot de passe. | Demander le mot de passe dans la boîte de dialogue et appeler `POST /privacy/delete-account/` avec `{"password": "..."}`. `204` : purger le stockage local (jetons, cache, file hors ligne) puis revenir à la connexion. `400` : « Mot de passe incorrect ». |
| A3 | même fichier | Textes **inventés** : « Dernière modification : il y a 3 mois » et « 1 appareil actif ». La tuile « Appareils connectés » est un bouton mort (`onTap: () {}`). | Supprimer ce faux sous-titre (le serveur ne fournit pas la date) et retirer la tuile « Appareils connectés ». |
| A4 | mêmes dialogues | Les erreurs s'affichent brutes : `Erreur: DioException [...]`. | Afficher un message clair en français : réseau (« Connexion faible. Réessayez. »), mot de passe incorrect, erreur serveur. Ne jamais afficher une exception brute. |
| A5 | `mobile/android/app/src/main/AndroidManifest.xml` | `usesCleartextTraffic="true"` est dans le manifeste **principal** : une application publiée accepterait le trafic non chiffré. | Garder cette option **uniquement** en développement : la déplacer dans `mobile/android/app/src/debug/AndroidManifest.xml`. |

Pour A1 et A2, ajoute un test (faux serveur avec `httpClientAdapter`, comme dans `test/auth_refresh_test.dart`) qui vérifie le **chemin appelé** et le comportement sur 204 et 400.

### 🔵 B. Nouvelles tâches (par ordre de priorité pour la soutenance)

#### Tâche n°7 — Écrans des fiches agronomiques (la plus importante pour la démo)

**Pourquoi.** Le serveur fournit déjà 19 fiches de cultures sourcées (`GET /api/agriculture/guides/`, voir `docs/06-Backend-API.md` §7.3). L'application ne les affiche nulle part. C'est ce que le jury voudra voir : « comment semer le niébé ? » avec sa source.

**À faire :**

1. Un écran **liste** des fiches : catégorie (légume, céréale, légumineuse, fruit) en filtre, champ de recherche (`?search=`), une carte par fiche (nom, catégorie, cycle si connu).
2. Un écran **détail** (`GET /api/agriculture/guides/<slug>/`) avec les rubriques dans cet ordre : présentation, zones, calendrier, sol et semis, eau, fertilisation, maladies et ravageurs, récolte, rendement. **Une rubrique vide n'est pas affichée** (vide signifie « non documenté », jamais une valeur inventée).
3. En bas, **toujours** : la section « Sources » (titre, éditeur, année, lien) et le texte de `limitations` bien visible. Si une source a `scope` différent de `senegal`, afficher « Référence hors Sénégal, à adapter ».
4. Les repères `[1]`, `[2]` dans les textes renvoient à la liste des sources : les laisser visibles.
5. **Hors ligne** : réutiliser ton `LocalCache` pour mettre en cache la liste et chaque fiche consultée, avec ton bandeau de date.
6. Aucune donnée en dur : tout vient de l'API. Les deux écrans produit qui utilisent `mock_product_database.dart` peuvent pointer vers la fiche correspondante (par `slug`) quand elle existe.

**Tests exigés :** lecture du modèle (champs vides, `sources`, `scope`), liste filtrée, détail sans rubrique vide, cache hors ligne (réseau coupé : la fiche s'affiche avec le bandeau).

#### Tâche n°8 — Assistant IA : afficher d'où vient la réponse

**Pourquoi.** Chaque réponse de `POST /api/ai/ask/` contient maintenant `origin` (`database` = depuis nos fiches ; `general` = conseil général sans source) et `sources`. L'écran de chat les ignore.

**À faire :** sous chaque réponse de l'assistant, un badge « Fiches Naatal Agro » (`database`) ou « Conseil général, non sourcé » (`general`) ; si `sources` n'est pas vide, une liste repliable (titre, éditeur, année). L'historique (`GET /api/ai/ask/`) doit afficher les mêmes badges. Le texte `response` contient déjà le pied « Sources : » : ne pas l'afficher deux fois (ou masquer ce pied dans le texte et utiliser la liste).

**Tests exigés :** modèle d'interaction avec et sans `sources`, affichage du badge selon `origin`.

#### Tâche n°6 — « Mon Dashboard » : retirer les valeurs inventées

**Pourquoi.** `mon_dashboard_screen.dart` affiche des valeurs écrites à la main : « 2 450 000 FCFA », « +12 % par rapport au mois dernier », des stocks (« Oignon Local 2,5 tonnes »), des conseils de l'IA et des « tendances » écrits en dur. Un utilisateur réel verrait les chiffres d'un autre.

**À faire :**
- Chiffre d'affaires, revenus et dépenses : `GET /api/finances/summary/` (fournisseur `finances_provider.dart` déjà présent).
- Stock : `GET /api/inventory/` (fournisseur `inventory_provider.dart` déjà présent).
- « Naatal IA » et « Tendances & Investissements » : aucune API ne fournit ces textes. **Supprimer** ces deux sections (ou les remplacer par un bouton vers l'assistant). Aucun texte de conseil écrit en dur.
- Quand il n'y a pas de données : un état vide clair (« Aucune vente enregistrée »), jamais des zéros inventés ni des exemples.
- Le `RefreshIndicator` doit relancer réellement les requêtes (`ref.invalidate(...)`).

**Tests exigés :** écran avec données (faux fournisseurs), état vide, erreur réseau avec bouton « Réessayer ».

#### Tâche n°9 — Consentement et export des données

**À faire :**
1. **Inscription** : une case à cocher « J'accepte la politique de confidentialité » avec un lien qui affiche le texte (`GET /api/privacy/policy/`, champs `version` et `content`). Envoyer `"privacy_accepted": true` dans la requête d'inscription. Inscription impossible sans la case cochée.
2. **Réglages, « Sécurité & Confidentialité »** : une ligne « Télécharger mes données » qui appelle `GET /api/privacy/export/` et propose d'enregistrer ou partager le fichier JSON.

Dès que la case de consentement est livrée, le serveur passera `PRIVACY_CONSENT_REQUIRED` à `True` (c'est Claude qui le fait, ne pas toucher au backend).

**Tests exigés :** l'inscription envoie `privacy_accepted`, le bouton d'inscription est désactivé sans consentement.

### ⚪ Rappels

- Laisser **tels quels** les deux écrans SMS simulés (« Mot de passe oublié » et code OTP) : c'est volontaire (voir plus haut).
- Ne pas toucher au dossier `web/` ni lancer de build web : le mobile uniquement.
- Un commit par sujet, fichiers ajoutés un par un (jamais `git add .`), `flutter analyze` sans problème et `flutter test` à 100 % avant chaque `git push origin pathe_fall`.
- Ordre conseillé : **A1 à A5, puis n°7, n°8, n°6, n°9**. Si le temps manque, mieux vaut n°7 et n°8 bien faits que quatre tâches à moitié.
