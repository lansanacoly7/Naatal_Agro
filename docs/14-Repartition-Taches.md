# Naatal Agro — Répartition des tâches Antigravity / Claude

| Informations | Valeur |
|--------------|---------|
| Projet | Naatal Agro |
| Document | Répartition des tâches entre les deux agents |
| Référentiel de comportement | `.agents/antigravity_behaviour.md` (18 règles) et `.agents/AGENTS.md` |
| Contraintes fixées par le propriétaire | Aucune limite de temps. Mobile d'abord, web ensuite. SQLite jusqu'à la fin, PostgreSQL uniquement au déploiement. Relecture des commits à la demande. |

---

# 1. Principes

1. **Périmètre unique : Naatal Agro.** Aucun contenu, aucune notion ni aucun fichier étranger au projet.
2. **Aucune fonctionnalité sans spécification.** Toute nouvelle fonctionnalité est d'abord décrite dans `docs/` (voir `AGENTS.md`, règle « Aucun code non spécifié »).
3. **« Terminé » signifie prouvé** (règles 1, 8 et 15) : code écrit, tests exécutés et verts, analyse statique propre, migrations à jour, documentation mise à jour. La preuve (sortie des commandes) est citée dans le message de commit ou de compte rendu.
4. **Aucune erreur cachée** (règle 14) : pas de `catch` vide, pas de `catchError((_) {})`, pas d'exception avalée. Toute erreur est journalisée ou affichée.
5. **Aucune valeur simulée affichée comme réelle** (règle 17) : les écrans affichent des états vides ou d'erreur explicites, jamais de fausses données.
6. **Priorités V1** (ordre de `AGENTS.md`) : authentification, tableau de bord, cultures, marchés, météo, carte, assistant IA, notifications, profil.

---

# 2. Forces de chaque agent et rôles

| | Antigravity | Claude |
|---|---|---|
| **Forces** | Travail dans l'IDE : écriture rapide de code Flutter, écrans, états de chargement et d'erreur, essais sur émulateur ou téléphone, Docker, scripts d'infrastructure, branchement de la CI. | Relecture critique, conception des contrats d'API, sécurité et permissions, tests backend, cohérence entre documents et code, rédaction technique, vérification des affirmations. |
| **Limites à encadrer** | Tendance à déclarer « terminé » sans preuve et à noter son propre travail trop haut. Tendance à regrouper plusieurs sujets dans un commit et à utiliser `git add .`. | N'exécute que sur demande du propriétaire. Ne peut pas voir un écran réel : les rendus visuels sont validés par Antigravity ou par le propriétaire. |
| **Rôle** | **Développeur d'exécution : mobile et infrastructure** | **Architecte et relecteur : contrat d'API, backend, qualité, documentation** |

---

# 3. Propriété des dossiers (évite les collisions)

| Dossier | Propriétaire | Règle |
|---|---|---|
| `mobile/lib/`, `mobile/web/`, `mobile/test/` (écrans, widgets, navigation) | **Antigravity** | Claude propose et relit, ne modifie pas sans accord. |
| `infra/`, `docker-compose.yml`, `backend/Dockerfile`, `scripts/*.sh`, `.github/workflows/` | **Antigravity** | Claude relit la sécurité (secrets, ports, utilisateurs). |
| `backend/apps/`, `backend/core/`, tests backend, `database/` | **Claude** | Antigravity signale un besoin, Claude le spécifie puis l'implémente. |
| `docs/`, `ai/`, `README.md` | **Claude** | Antigravity met à jour la documentation de ses propres changements dans la section concernée. |
| `web/` | **Reporté** (voir §5) | Aucune modification fonctionnelle avant la fin du mobile. |
| Couche de données mobile (`mobile/lib/features/*/data`, `core/network`) | **Partagée** | Claude spécifie le contrat d'API dans `docs/06-Backend-API.md` avant tout changement. Antigravity l'implémente. |

## Règles de collaboration

1. Avant de commencer, récupérer `origin/test` (`git fetch`) et lire `git status` pour voir ce que l'autre modifie.
2. **Un commit = un sujet.** Format : `type(portée): résumé` (feat, fix, refactor, test, docs, chore, ci).
3. **Jamais `git add .` ni `git add -A`.** Ajouter uniquement les fichiers de sa propre tâche.
4. Ne jamais modifier un fichier d'un dossier que l'autre possède sans le lui demander via le propriétaire du projet.
5. Aucun secret dans le dépôt (clés, tokens, mots de passe, y compris « par défaut »). Les valeurs viennent de `.env`, modèle dans `.env.example`.
6. Pas d'auto-évaluation chiffrée. Un état est « fait », « en cours » ou « à faire », avec preuve.
7. **Relecture à la demande uniquement** : sur l'ordre « contrôle » du propriétaire, Claude relit les nouveaux commits d'`origin/test` selon les 18 règles et rapporte les écarts factuels.

---

# 4. Base de données : SQLite jusqu'à la fin, PostgreSQL au déploiement

- **Développement, tests et CI : SQLite** (`USE_POSTGRES=False`), jusqu'à la dernière phase.
- **Règle de compatibilité dès maintenant :** aucun SQL brut, aucune fonction propre à un moteur. Uniquement l'ORM Django, pour que la bascule soit sans réécriture.
- **Phase finale « Bascule PostgreSQL »** (une seule fois, à la fin) :
  1. exécuter la suite de tests complète sur PostgreSQL (service PostgreSQL dans la CI) ;
  2. migrer les données de démonstration (`seed.py`) ;
  3. valider `docker compose up` avec PostgreSQL 16, sauvegarde et restauration réelles ;
  4. mettre à jour `README.md` et `docs/05-Database-Design.md`.
- Tant que cette phase n'est pas atteinte, ne pas changer `USE_POSTGRES` par défaut et ne pas modifier les modèles pour un moteur précis.

---

# 5. Mobile d'abord, web ensuite

- Toute l'énergie va au mobile jusqu'à ce que ses blocs soient terminés (voir §6).
- `web/` reste en l'état : seule la compilation (`npm run build`) est maintenue verte dans la CI. Aucune nouvelle fonctionnalité web, aucune dépense d'effort de conception.
- Le web redémarre ensuite, par modules (`web/modules/*`), sur la base d'une API déjà stabilisée par le mobile.

---

# 6. Répartition par bloc

Légende : **AGY** = Antigravity, **CLA** = Claude. La colonne « Définition de terminé » est vérifiée par une commande ou une démonstration, pas par une note.

| Bloc | Responsable | Contenu pour Naatal Agro | Définition de terminé |
|---|---|---|---|
| UI/UX | AGY | États de chargement, vides, d'erreur et hors ligne cohérents sur chaque écran. Actualisation par tirage. Indicateur de connexion. Écrans à une seule fonction (`AGENTS.md`). Écrans trop longs découpés en widgets. | `flutter analyze` à zéro ; test de widget par écran critique ; passage sur émulateur et sur un vrai téléphone. |
| Contenus agronomiques | CLA (rédaction et sources) puis AGY (écran) | Fiches des cultures (cycle, besoins en eau, fertilisation, ravageurs) avec sources citées (ISRA, ANCAR, FAO). Toute affirmation non sourcée est marquée « à vérifier ». Remplace `mock_product_database.dart`. | Plus aucune donnée simulée dans les écrans produit ; sources visibles dans la fiche. |
| Architecture | CLA | Contrats d'API écrits avant le code ; frontières entre modules ; revue des dépendances entre apps Django et entre features Flutter. | `docs/04`, `docs/06`, `docs/07` à jour ; aucun import circulaire. |
| Base de données | CLA | Modèles, contraintes, index utiles sur les champs filtrés (dates, clés étrangères), compatibilité SQLite/PostgreSQL (§4). | Migrations à jour (`makemigrations --check`) ; pas de SQL brut. |
| API | CLA (spécification et backend) puis AGY (mobile) | **Pagination** exigée par les documents `04`, `05`, `06`, `07` et aujourd'hui absente : à spécifier, implémenter côté backend, puis adapter ensemble les écrans de liste. Format d'erreur homogène. Codes HTTP cohérents. | Tests d'API ; documentation d'API à jour ; mobile lit les listes paginées. |
| Authentification | CLA | Politique de mots de passe, expiration des jetons, rotation, déconnexion qui invalide le jeton (liste noire), limites de débit. | Tests : mauvais mot de passe, jeton expiré, rotation, limite atteinte. |
| Permissions | CLA | Isolation par utilisateur sur toute ressource privée ; tests d'accès croisé pour chaque point d'accès. | Un test « utilisateur A ne voit/modifie pas les données de B » par ressource. |
| Données personnelles et consentement | CLA (texte et modèle) puis AGY (écran) | Notice de confidentialité, consentement à l'inscription, droit d'accès et d'effacement du compte. Le texte juridique est marqué « à faire valider » ; aucune affirmation de conformité sans validation. | Écran de consentement ; endpoint de suppression de compte testé. |
| Analytics | CLA (backend) puis AGY (écrans) | Tableau de bord exploitant : surfaces, cultures actives, rentabilité (recettes moins charges), météo locale. Agrégations SQL, pas de boucles Python. | Tests de calcul avec jeux de données connus. |
| Tableau de bord administrateur | CLA | Administration Django utile : filtres, recherche, lecture seule sur les données sensibles. | `list_filter` et `search_fields` présents sur les modèles métier. |
| Notifications | AGY (mobile Firebase) puis CLA (backend, relecture) | Enregistrement du jeton FCM côté téléphone (`firebase_messaging`), réception, ouverture de l'écran concerné. Envoi côté backend hors du cycle de requête. **Exige un projet Firebase fourni par le propriétaire.** | Notification reçue sur un appareil réel depuis le backend. |
| Performance | CLA | Requêtes sans N+1, index, pagination, mesure des temps de réponse des points d'accès principaux. | Rapport de mesure avant/après dans `docs/`. |
| Scalabilité | CLA (revue) et AGY (conteneurs) | Application sans état, travaux longs hors requête, configuration par variables d'environnement. | Revue documentée ; conteneur démarre avec deux instances. |
| Sauvegardes | AGY | Scripts de sauvegarde/restauration exécutés réellement sur SQLite, puis PostgreSQL à la bascule. | Une restauration réelle réussie, tracée. |
| Supervision | AGY (exécution) et CLA (revue) | Point de santé, journaux structurés, niveau de journalisation configurable. | Le point de santé répond 200 et 503 base coupée (test). |
| Tests | CLA (backend) et AGY (mobile) | Backend : un fichier de tests par app avec cas limites et accès croisés. Mobile : tests de modèles, de la couche réseau et des écrans critiques. | Toutes les suites vertes ; chaque correction de bug vient avec son test. |
| CI/CD | AGY (workflow) et CLA (revue) | Tests backend, migrations, contrôle de déploiement, analyse et tests Flutter, build web. Service PostgreSQL ajouté à la bascule. | Pipeline vert sur `test` et `main`. |
| Déploiement | AGY | Images Docker réellement construites et lancées, démarrage de bout en bout (base, backend, proxy). Secrets obligatoires. | `docker compose up` démarre ; `/api/health/` répond ; capture de la sortie conservée. |
| Documentation | CLA | README, documents `docs/`, `.env.example`, guide d'installation vérifié sur une machine neuve, documentation d'API. | Un lecteur suit le README jusqu'à une application qui tourne. |

---

# 7. Points ouverts connus (issus des audits)

| Point | Responsable | État |
|---|---|---|
| Régénérer `SECRET_KEY` et `DB_PASSWORD` (ont été publics) | Propriétaire | À faire |
| Révoquer le token GitHub présent dans `backend/.env` | Propriétaire | À faire |
| Renseigner les clés Groq, Gemini, OpenWeather | Propriétaire | À faire |
| Valider le modèle Gemini avec une vraie clé | CLA après réception de la clé | À faire |
| Décision sur la branche `origin/pathe_fall` (ne pas fusionner telle quelle) | Propriétaire | À décider |
| Mise à jour du rapport pour le retrait du module B2B | Propriétaire et CLA | À faire |
| Construction Docker réelle (Docker Desktop à lancer) | AGY | À faire |
| Pagination (documents ↔ code) | CLA puis AGY | À faire |
| Écrans produit encore sur données simulées : brancher `mock_product_database.dart` sur `/api/agriculture/guides/` (API prête, 5 fiches sourcées) | AGY | À faire |
| Compléter la fiche riz (calendrier, eau, maladies) et ajouter d'autres cultures, avec sources | CLA | À faire |
| Notifications push sur téléphone | AGY, après projet Firebase | À faire |
| Écrans mobiles de confidentialité : case de consentement à l'inscription, export de mes données, suppression du compte (API prête : `/api/privacy/`) | AGY | À faire |
| Passer `PRIVACY_CONSENT_REQUIRED=True` une fois la case de consentement livrée | CLA | À faire |
| Identité du responsable du traitement et contact dans la politique de confidentialité, validation juridique du texte | Propriétaire | À faire |
