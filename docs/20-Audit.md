# Audit complet de Naatal Agro (branche `test`, 2026-10-13)

## 0. Périmètre et méthode

**Lu en entier**
- Le backend (settings, 10 apps, services IA, commandes, scripts de données, tests).
- Le noyau mobile (réseau, routeur, cache, thème, constantes, manifestes), toute la couche données mobile, et la plupart des écrans (tableau de bord, cultures, marchés, stocks, finances, IA, profil, auth).
- La CI, le nginx, les docker-compose, les scripts, `.agents/`, le README et les docs de pilotage (02, 13, 14, 18).

**Exécuté**
- Tests backend : 207 tests, tous verts (1 sauté), couverture 93 %.
- Tests mobile : 55 verts. `flutter analyze` : propre.
- `makemigrations --check` propre. `check --deploy` : 2 avertissements (SECRET_KEY de test et HSTS preload).
- Sondes sur une base SQLite mémoire, avec les payloads exacts envoyés par le mobile.
- Mesures de poids d'API sur `db.sqlite3` en lecture seule.

---

## 1. Verdict

Le backend est solide : sécurité, isolation des utilisateurs, tests. Le mobile affiche plusieurs données codées en dur ou simulées.

Trois constats dominent :
1. **Les cotations de marché sont des données de simulation**, et la documentation doit être transparente là-dessus.
2. **Deux flux centraux sont à corriger** : « Vendre ce stock » avec le payload mobile, et la modification du nom dans le profil.
3. **La liaison entre données doit être renforcée** au-delà des comparaisons de noms textuelles.

---

## 2. Ce qui marche (prouvé)

| Domaine | Preuve |
|---|---|
| Auth JWT : inscription, connexion, rotation et liste noire, déconnexion, changement de mot de passe, limitation de débit | tests + lecture de `apps/users/views.py` |
| Isolation par utilisateur (cultures, finances, stocks, notifications, IA) | tests d'accès croisé |
| Fiches agronomiques : 19 fiches, sources, aucune citation `[n]` cassée, validation humaine des propositions (`KnowledgeProposal`) | analyse du JSON + `knowledge_review.py` |
| IA « fiches d'abord » : retrieval déterministe, citations validées, repli explicite en « conseil général » | `services.py`, `knowledge.py` |
| Récolte → stock → notification | testé et vérifié par sonde |
| Vente avec champs natifs : stock décrémenté, anti-survente | testé et vérifié par sonde |
| Export et suppression de compte (API) | tests |
| Administration Django (filtres, recherche, file de validation) | lecture |
| Migrations à jour, health check, journalisation, throttling | exécuté |
| Cache hors ligne des cultures, du profil et des fiches ; rejeu de file | tests mobile |

---

## 3. Plan d'actions correctives immédiates (P0)

1. **Vente de stock depuis le mobile (Payload compatibilité) :**
   - Corriger `SaleSerializer` pour accepter et traiter proprement le payload du mobile (`product_name`, `quantity`, `unit_price`, `sale_date`, `buyer`).
   - Éliminer la création de cultures fantômes.
   - Synchroniser atomiquement la transaction de revenu (`Transaction.objects.create(transaction_type='income')`).
2. **Modification du profil (`full_name`) :**
   - Permettre à `UserSerializer` / `UserUpdateSerializer` d'écrire `first_name` et `last_name` lors de l'envoi de `full_name`.
3. **Permissions réseau Android :**
   - Ajouter `INTERNET` dans `AndroidManifest.xml` principal (pas seulement debug).
4. **Mode hors-ligne cohérent :**
   - Traiter le code HTTP 202 comme succès (mis en file d'attente) dans `harvestCrop`, `addCrop` et `recordSale`.
   - Purger la file d'attente lors de la déconnexion utilisateur.
5. **Nettoyage des contenus inventés et routes cassées :**
   - Supprimer le faux avertissement phytosanitaire universel de mildiou dans `crop_detail_screen.dart`.
   - Corriger la route de redirection vers les guides agronomiques (`/agriculture/guides/:slug`).
6. **Accès public aux prix des marchés :**
   - Permettre la consultation publique en lecture seule de `/api/markets/prices/` et `/api/markets/` pour le Web et les visiteurs.
7. **Transparence et vérité technique dans `docs/18-Preparation-Soutenance.md` :**
   - Déclarer honnêtement la nature des données de marché (simulation académique) et le périmètre des perspectives (SMS OTP).
