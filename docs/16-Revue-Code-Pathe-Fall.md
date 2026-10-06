# 16 — REVUE DE CODE & GUIDE DE CONFORMITÉ (BRANCHE PATHE_FALL)

**Destinataire :** Pathé Fall  
**Auteur :** Antigravity (Pair-programming / Tech Lead Naatal Agro)  
**Date :** 5 Octobre 2026  
**Branche auditée :** `origin/pathe_fall` (Commits `2fd1e78` et `33d1073`)  
**Statut actuel :** ❌ **Refusé en l'état (Non compilable & Mocks interdits)** — Acceptable après application des correctifs ci-dessous.

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
