# Naatal Agro — Préparation de la soutenance : état prouvé du projet & grille de démonstration

| Informations | Valeur |
|--------------|---------|
| Projet | Naatal Agro |
| Document | Préparation de la soutenance (état prouvé, vérifié et honnête du projet) |
| Objectif | Réussir la soutenance avec une démonstration technique irréprochable et un rapport transparent |
| Règle d'or | Chaque affirmation s'appuie sur une preuve concrète (tests automatisés, code audité, comportement réel vérifié). |

---

# 1. Principes Directeurs & Démarche d'Ingénierie

Une application d'ingénierie logicielle mature se distingue d'un simple prototype par sa rigueur architecturale, la robustesse de ses flux transactionnels, son isolation des données et sa transparence méthodologique :

- **Rigueur des flux transactionnels :** Les opérations critiques (récolte, vente de stock, mouvements financiers) sont exécutées de manière atomique en base avec des garde-fous stricts (anti-survente, cohérence du stock et des recettes).
- **Interconnexion 360° réelle :** Cultures ↔ Fiches agronomiques ↔ Récoltes ↔ Stocks d'inventaire ↔ Ventes ↔ Transactions financières ↔ Météo ↔ Notifications.
- **Honnêteté scientifique et technique :** Aucune fausse affirmation devant le jury. Les fonctionnalités pleinement opérationnelles sont démontrées avec fierté ; les jeux de données de charge (stress test des marchés) et les flux tiers payants (passerelle SMS) sont expliqués avec clarté comme des choix d'ingénierie et de prototypage industriel.

---

# 2. État par Domaine & Preuves Formelles

Légende : **Fait** = prouvé par des tests automatisés et exécution réelle ; **Perspective / Choix assumé** = documenté en perspective technique.

| Domaine | État | Preuve Technique | Remarques & Perspectives |
|---|---|---|---|
| **Authentification & Sécurité** | **Fait** | Jetons JWT à rotation, blacklist, changement de MDP, mise à jour du profil (`full_name`), isolation stricte par utilisateur (`apps/users`) | Algorithme PBKDF2 pour les mots de passe. Clés de production à renouveler lors du déploiement public. |
| **Confidentialité & RGPD / CDP** | **Fait** | Consentement enregistré, export complet JSON en clair (standard d'interopérabilité et de portabilité), suppression définitive du compte (`apps/privacy`) | Respect des directives de la CDP du Sénégal (loi 2008-12). |
| **Fiches Agronomiques & RAG** | **Fait** | 19 fiches techniques sourcées (ISRA, ANACIM, FAO) avec citations vérifiées `[n]`, validation humaine des propositions (`apps/agriculture`) | Toutes les sources sont vérifiables dans le fichier `guides.json`. |
| **Cycle Récolte ↔ Stock ↔ Vente** | **Fait** | `/crops/{id}/harvest/` incrémente le stock ; `/finances/sales/` décrémente le stock avec garde-fou anti-survente, sans culture fantôme, et crée la `Transaction` de revenu liée (`apps/finances/tests.py`) | Restitution automatique du stock en cas de suppression d'une vente. |
| **Marchés & Cotations** | **Fait (Architecture & Benchmark)** | Modèles multi-marchés (19 marchés régionaux), API REST paginée avec accès public en lecture. 20 615 cotations générées pour stress-tester l'indexation SQL et les courbes | Données simulées par série temporelle à des fins de benchmark de charge. Schéma prêt pour l'ingestion de flux réels (SIM / CSA). |
| **Assistant IA Contextuel** | **Fait** | RAG déterministe s'appuyant en priorité sur les fiches agronomiques, quotas anti-abus (30 req/h), bascule Groq/Gemini (`apps/ai_assistant`) | Clés de production (Gemini / Groq) configurables par variables d'environnement. |
| **Mode Hors-ligne (Offline Sync)** | **Fait** | File d'attente FIFO (SharedPreferences), réponse HTTP 202 Accepted, rejeu automatique au retour réseau via `SyncService`, purge à la déconnexion (`mobile/lib/core/network`) | Gestion propre sans génération de faux doublons. |
| **Tableau de Bord Web (React)** | **Fait** | Dashboard public connecté à l'API DRF (`/api/markets/prices/`, `/api/agriculture/guides/`), proxy Vite configuré (`web/src/App.tsx`) | Affiche les cotations et guides en direct depuis la base de données. |
| **Vérification SMS (OTP)** | **Perspective assumée** | Formulaire mobile existant avec simulation éducative locale | La souscription d'une passerelle SMS opérateur payante (Orange SMS API / Twilio) est prévue pour la phase commerciale. |
| **Tests & Qualité Globale** | **Fait** | **Tests Backend Django (100% passés)** + **Tests Flutter (100% passés)** + `flutter analyze lib` propre | Couverture de test robuste sur tous les flux métiers. |

---

# 3. Démonstration Type à Dérouler Devant le Jury (Scénario 360°)

1. **Création d'une culture liée à un guide agronomique :**
   - L'agriculteur crée une parcelle d'oignon dans sa région.
   - En sélectionnant le guide officiel « Oignon (Niayes) », le cycle recommandé (70 à 120 jours) et les informations culturales s'affichent de façon transparente.
2. **Consultation des marchés et cotations :**
   - L'agriculteur consulte les prix des produits sur les différents marchés régionaux (Castors, Tilène, Kaolack...) via les graphiques connectés à l'API.
3. **Enregistrement d'une récolte :**
   - L'agriculteur enregistre une récolte (ex : 500 kg).
   - Le statut de la culture est mis à jour, le stock d'inventaire est automatiquement créé ou incrémenté, et une notification interne est émise.
4. **Vente du stock et impact financier atomique :**
   - Depuis son inventaire, l'agriculteur clique sur « Vendre ce stock » (ex : 200 kg à 350 FCFA/kg).
   - Le stock passe de 500 kg à 300 kg.
   - La recette (+70 000 FCFA) génère automatiquement une transaction de revenu dans le bilan financier.
   - Si l'agriculteur tente de vendre plus que son stock restant (ex : 400 kg alors qu'il n'en reste que 300), le serveur rejette l'opération avec une erreur claire « Stock insuffisant ».
5. **Démonstration du mode hors-ligne :**
   - En coupant la connexion réseau : l'ajout d'une culture ou la vente d'un stock est intercepté et mis en file d'attente locale (HTTP 202).
   - À la réactivation du réseau : synchronisation automatique et transparente par le `SyncService`.
6. **Consultation du Portail Web :**
   - Ouverture du portail React connecté au backend montrant en direct les prix des marchés et les guides agronomiques.

---

# 4. Réponses Clés aux Questions du Jury

- **Q : Vos données de marché sont-elles réelles ou simulées ?**
  *R :* La structure des marchés (19 marchés répartis dans les régions du Sénégal) et les produits sont fidèles à la réalité nationale. Les 20 000 relevés historiques ont été générés à l'aide d'un script de simulation stochastique à partir de prix de référence indicatifs. Cela nous a permis de dimensionner l'application, de stress-tester l'indexation SQL sur un volume réaliste de plusieurs années et de valider les performances d'affichage des graphiques. Le schéma de données est entièrement prêt à ingérer les relevés officiels du SIM/CSA dès qu'une convention d'accès aux données sera établie.

- **Q : Que se passe-t-il si un agriculteur vend plus que son stock disponible ?**
  *R :* Le backend DRF bloque strictement la transaction au niveau applicatif et base de données avec une erreur HTTP 400 et le message « Stock insuffisant ». Les tests unitaires valident ce garde-fou critique pour éviter toute survente comptable.

- **Q : Pourquoi le code SMS OTP accepte-t-il n'importe quel code à 4 chiffres ?**
  *R :* C'est un choix de gestion de projet assumé : l'intégration d'un SMS Gateway opérateur (type Orange API ou Twilio) engendre des coûts de transaction récurrents par SMS envoyé, ce qui n'était pas justifiable financièrement en phase de développement académique. L'interface et l'expérience utilisateur sont prêtes, et le coeur de la sécurité (hachage des mots de passe en PBKDF2, jetons JWT signés avec liste noire de révocation) est 100% opérationnel et testé.

- **Q : Comment garantissez-vous la conformité CDP / RGPD ?**
  *R :* Nous avons implémenté les droits fondamentaux prévus par la CDP du Sénégal (loi 2008-12) : chaque utilisateur peut exporter l'intégralité de ses données personnelles dans un format ouvert JSON (droit à la portabilité) ou demander la purge irréversible et complète de son compte et de ses données (droit à l'oubli), sécurisée par une confirmation de son mot de passe.
