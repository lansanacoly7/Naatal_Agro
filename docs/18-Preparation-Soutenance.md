# Naatal Agro — Préparation de la soutenance : ce qui est fait, ce qui reste, ce qui est prévu

| Informations | Valeur |
|--------------|---------|
| Projet | Naatal Agro |
| Document | Préparation de la soutenance (état prouvé du projet) |
| Objectif retenu | Réussir la soutenance avec une démonstration solide et un rapport qui décrit honnêtement ce qui est fait et ce qui est prévu |
| Règle | Chaque ligne « fait » s'appuie sur une preuve (test, commande, fichier). Aucune note chiffrée. |

---

# 1. Principe

Une application « prête pour la production » se distingue d'un prototype par sa sécurité, sa résilience, sa surveillance et sa
capacité à évoluer. Pour un projet de fin de formation, on ne vise pas tout, on **choisit** :

- **À terminer avant la soutenance** : ce que le jury verra ou testera, et tout ce qui pourrait donner une fausse impression.
- **À présenter comme « prévu »** : ce qui est conçu ou documenté, mais volontairement hors du périmètre actuel.

Dire clairement ce qui n'est pas fait est un point positif devant un jury ; une fonctionnalité qui prétend marcher sans marcher
est un point négatif.

---

# 2. État par domaine

Légende : **Fait** = prouvé par un test ou une commande ; **Partiel** = existe avec des limites connues ; **Absent**.

| Domaine | État | Preuve | Reste à faire avant la soutenance |
|---|---|---|---|
| Authentification | **Fait** | Jetons à rotation avec liste noire, déconnexion qui invalide le jeton, changement de mot de passe, politique de mot de passe, numéro validé (tests `apps/users`) | Régénérer les secrets qui ont été publics (propriétaire) |
| Autorisations | **Fait** | Isolation des données par utilisateur sur chaque ressource privée, tests d'accès croisé | — |
| Protection contre l'abus | **Fait** | Limites de débit (connexion 10/min, IA 30/h), taille des requêtes IA bornée | — |
| Secrets | **Partiel** | Aucune clé dans le code ni dans l'application mobile ; modèle `.env.example` | Rotation des anciens secrets, révocation du token GitHub (propriétaire) |
| Données personnelles | **Partiel** | API de politique, d'export et de suppression de compte, consentement enregistré (tests `apps/privacy`) | Écrans mobiles correspondants ; identité du responsable de traitement et validation juridique du texte |
| Contenus agronomiques | **Partiel** | 8 fiches sourcées, test automatique de traçabilité des sources | Cultures manquantes (maïs, niébé, pomme de terre, chou…) : sources récentes à fournir |
| Assistant IA | **Fait** | Réponses d'abord depuis la base, citations obligatoires, informations manquantes signalées, quotas, bascule entre modèles (tests `apps/ai_assistant`) | Tester avec de vraies clés ; les clés ne sont pas configurées sur la machine de développement |
| Hors ligne (écriture) | **Fait** | File d'attente des actions et rejeu au retour du réseau (tests `sync_service`) | — |
| Hors ligne (lecture) | **Absent** | Aucun cache de données : sans réseau, les listes affichent une erreur | Tâche confiée à Pathé (`docs/16-Revue-Code-Pathe-Fall.md`, tâche n°5) : cache des cultures au minimum ; sinon le présenter comme « prévu » |
| Gestion des erreurs | **Partiel** | États de chargement, vide et erreur sur les écrans ; indicateur hors ligne | Gestionnaire d'erreurs global (aucun écran blanc sur exception) |
| Vérification par SMS (OTP) et mot de passe oublié | **Simulé volontairement** | « Mot de passe oublié » affiche « Instructions SMS envoyées » sans appel au serveur ; l'inscription demande un code OTP ni envoyé ni vérifié | Implémentation SMS prévue (fournisseur à choisir). D'ici là, présenter ces écrans comme simulés (voir §3) |
| Tests | **Fait** | Plus de 170 tests backend, tests mobiles (jetons, file hors ligne, pagination, déconnexion, tableau de bord), exécutés en CI | Un test de bout en bout mobile vers serveur est prévu, pas fait |
| Intégration continue | **Fait** | Tests, migrations, contrôle de déploiement, analyse Flutter, build web | Le déploiement automatique est prévu, pas fait |
| Journaux et santé | **Partiel** | Journalisation configurée, point de santé `/api/health/` | Aucun suivi des plantages ni alerte : à présenter comme prévu |
| Sauvegarde et reprise | **Partiel** | Scripts de sauvegarde et de restauration écrits | Une restauration réelle à exécuter et à tracer ; définir et écrire les durées acceptables de perte de données et d'indisponibilité |
| Déploiement | **Partiel** | Fichiers Docker et nginx, contrôle de configuration de production | Construire et lancer réellement les conteneurs ; la base de données reste SQLite jusqu'à la fin, PostgreSQL au déploiement |
| Application Android | **Partiel** | Compile et passe l'analyse | La version de publication est signée avec la clé de débogage : à présenter comme « non distribuable en l'état » |
| Documentation | **Partiel** | README, documents `docs/`, API d'authentification, d'IA et de fiches à jour | Guide utilisateur ; mise à jour du rapport après le retrait du module B2B |

---

# 3. Écrans simulés volontairement (décision du propriétaire)

Deux écrans sont conservés tels quels **en attendant l'implémentation de la vérification par SMS** :

| Écran | Ce qu'il affiche | Réalité aujourd'hui |
|---|---|---|
| Connexion, « Mot de passe oublié ? » | « Instructions SMS envoyées au … » | Aucun appel au serveur, aucun SMS |
| Inscription, étape « Vérification » | « Un code à 4 chiffres a été envoyé au … » | Aucun code envoyé ni vérifié ; n'importe quels 4 chiffres passent |

Cette simulation est un choix assumé, pas un oubli. Pour qu'elle ne se retourne pas contre le projet devant le jury :

- **Le dire avant qu'on le découvre** : « ces deux écrans sont des maquettes, l'envoi réel de SMS est la prochaine étape ».
- Ne pas présenter ces parcours comme fonctionnels dans le rapport : les classer dans les perspectives (§4).
- Ne pas modifier ces écrans par erreur : l'instruction est écrite dans `docs/16-Revue-Code-Pathe-Fall.md`.
- Quand le SMS sera implémenté (fournisseur, clés et coût à décider par le propriétaire), le serveur devra gérer : génération et
  expiration du code, limite de tentatives, limite d'envois par numéro, et jamais le code dans une réponse de l'API.

---

# 4. À présenter comme « prévu » (perspectives du rapport)

Conçu ou documenté, volontairement hors du périmètre actuel :

1. Vérification du numéro et réinitialisation du mot de passe par SMS.
2. Notifications push sur téléphone (le serveur sait les envoyer ; l'application ne s'enregistre pas encore).
3. Cache de lecture hors ligne.
4. Suivi des plantages et alertes (Sentry ou Crashlytics).
5. Recherche web de l'assistant pour les informations absentes de la base, après validation (voir `docs/09-AI-System.md` §18.4).
6. Marketplace B2B, acheteurs et paiements Mobile Money (phase 3 de la feuille de route).
7. Environnement de test intermédiaire, déploiement automatique, publication sur les magasins d'applications.
8. Passage à PostgreSQL en production.
9. Tableau de bord web (le mobile est la priorité).

---

# 5. Messages à tenir devant le jury

- « L'assistant répond d'abord depuis notre base de fiches sourcées ; quand l'information manque, il le dit au lieu d'inventer. »
- « Les données de chaque agriculteur sont isolées : nous avons des tests d'accès croisé pour chaque ressource. »
- « Les actions faites sans réseau sont conservées et rejouées au retour de la connexion. »
- « Nous avons volontairement retiré le module B2B pour recentrer la version 1 sur les producteurs. »
- « Ce qui n'est pas fait est listé dans nos perspectives : vérification par SMS, cache de lecture hors ligne, suivi des plantages. »

---

# 6. Liste de contrôle avant la démonstration

1. Branche `test` à jour, `python manage.py migrate` exécuté, base de démonstration remplie (`python seed.py`).
2. Clés d'API (Groq, Gemini, OpenWeather) renseignées dans `backend/.env` et assistant testé une fois.
3. Application lancée sur un vrai téléphone avec `--dart-define=API_BASE_URL=...` vers le serveur de démonstration.
4. Parcours à dérouler : inscription, connexion, ajout d'une culture, consultation d'une fiche, question à l'assistant, action hors ligne puis retour du réseau, déconnexion.
5. Parcours simulés ou non branchés, à présenter comme tels : mot de passe oublié, code OTP, notifications push.
6. Plan de repli si Internet tombe : base locale SQLite, assistant en mode « réponse depuis les fiches » (fonctionne sans service d'IA).
