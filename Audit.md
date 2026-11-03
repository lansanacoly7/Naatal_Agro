# AUDIT TECHNIQUE COMPLET, STRICT ET FACTUEL — GO / NO-GO AVANT FUSION VERS MAIN ET MISE EN PRODUCTION

## 1. TON RÔLE

Agis comme un **auditeur logiciel senior indépendant, architecte logiciel, expert en sécurité applicative, ingénieur QA et DevOps senior**.

Ta mission est d'effectuer un audit technique approfondi du projet actuellement ouvert dans le workspace, ainsi que de son dépôt GitHub et de son état Git réel.

Tu ne dois pas chercher à me faire plaisir. Tu dois chercher la vérité technique.

Je veux connaître l'état réel du projet, ses forces, ses faiblesses, ses risques, ses défauts et son niveau de préparation à la production.

L'objectif est de déterminer, avec des preuves vérifiables, si le projet peut être fusionné dans `main` et s'il est suffisamment fiable pour être déployé en production.

**Aucune complaisance. Aucune invention. Aucune conclusion non justifiée. Aucun faux sentiment de sécurité.**

## 2. RÈGLES ABSOLUES

### A. Auditer ce qui existe réellement

- Inspecte le code, les fichiers de configuration, les dépendances, les tests, la documentation et les workflows réellement présents.
- Vérifie le dépôt GitHub et les informations auxquelles tu as effectivement accès.
- Identifie la branche actuelle, la branche cible, les commits, les modifications locales et les éventuels conflits.
- Distingue clairement ce qui est implémenté, partiellement implémenté, simulé, incomplet ou absent.
- Ne déduis jamais qu'une fonctionnalité fonctionne simplement parce qu'un écran, une route, un composant ou une fonction existe.
- Ne prétends jamais avoir consulté GitHub, exécuté un test ou vérifié un service externe si tu ne l'as pas réellement fait.

Si une ressource est inaccessible, indique précisément la limite et poursuis l'audit sur les éléments disponibles.

### B. Interdiction d'inventer

Chaque constat important doit reposer sur une preuve vérifiable : fichier, emplacement dans le code, configuration, résultat de test, sortie de commande ou état Git.

Pour chaque problème, précise :
- **Constat :** ce qui a été observé.
- **Preuve :** fichier, ligne ou résultat concret.
- **Impact :** conséquence réelle ou risque technique.
- **Gravité :** critique, élevée, moyenne ou faible.
- **Correction :** action nécessaire, si elle est connue.

Distingue les faits confirmés, les risques plausibles, les hypothèses et les points non vérifiés.

Ne présente pas une absence de preuve comme la preuve d'un défaut. Par exemple, l'absence d'un outil de sécurité particulier ne signifie pas automatiquement que l'application est vulnérable.

Si tu ne peux pas confirmer un problème, indique « à vérifier » au lieu de l'affirmer.

### C. Préserver intégralement le projet

Cet audit est d'abord une mission d'inspection.

- Ne modifie aucun fichier pendant la phase d'audit initial.
- Ne supprime aucun fichier.
- Ne reformate pas automatiquement le code.
- N'effectue aucune migration de base de données.
- N'installe, ne désinstalle et ne mets à jour aucune dépendance sans autorisation.
- Ne modifie aucune configuration de production.
- Ne touche pas aux secrets et ne les affiche jamais.
- N'exécute aucune opération destructive.
- Ne change pas de branche et ne réinitialise pas le workspace.
- Ne fusionne, ne pousse et ne déploie absolument rien.

Tu dois préserver toutes les modifications locales, y compris celles qui ne sont pas encore commitées.

Si une vérification risque de modifier des données, d'appeler un service payant, de contacter un système de production ou d'écraser des fichiers, arrête-toi et signale le risque avant toute exécution.

## 3. PHASE 1 — IDENTIFICATION ET ÉTAT GIT

Commence par établir précisément le contexte du projet.

Vérifie :

1. Le nom du projet et sa structure réelle.
2. Le dépôt GitHub associé, son URL si disponible et son accessibilité.
3. La branche actuelle et la branche cible `main`.
4. Le commit actuel et le commit de référence de `main`.
5. Les commits présents sur la branche actuelle mais absents de `main`.
6. Les commits présents sur `main` mais absents de la branche actuelle.
7. Les fichiers modifiés, ajoutés, supprimés, non suivis ou ignorés.
8. Les modifications locales qui pourraient être perdues.
9. Les éventuels conflits de fusion déjà détectables.
10. L'état des pull requests, des checks CI/CD et des protections de branche, uniquement si ces informations sont accessibles.

Ne suppose pas que la branche actuelle est prête à être fusionnée.

Établis une distinction entre :
- L'état du workspace local.
- L'état de la branche distante de travail.
- L'état de la branche distante `main`.

Ne confonds jamais un workspace propre avec un projet sain.

## 4. PHASE 2 — ARCHITECTURE ET QUALITÉ DU CODE

Inspecte l'architecture réelle du projet.

Analyse notamment :

- La séparation des responsabilités.
- La cohérence entre les modules.
- La qualité des frontières entre frontend, backend, services et base de données, selon le projet.
- Les dépendances entre composants.
- Les duplications de logique.
- Le code mort ou inutilisé, lorsqu'il est identifiable.
- Les fichiers parasites ou obsolètes, en distinguant les éléments réellement inutiles des fichiers générés ou nécessaires.
- Les fonctions trop complexes.
- Les traitements incomplets.
- Les erreurs de gestion des exceptions.
- Les conventions de nommage.
- La lisibilité et la maintenabilité.
- La gestion de la configuration selon les environnements.
- La présence de valeurs codées en dur.
- Les problèmes de performance identifiables dans le code.

Vérifie également si l'architecture actuelle est adaptée à la taille et aux besoins réels du projet.

Ne recommande pas une refonte complète simplement parce qu'une autre architecture te semble plus moderne. Toute recommandation doit répondre à un problème concret.

## 5. PHASE 3 — FONCTIONNALITÉS ET PARCOURS UTILISATEUR

Établis l'inventaire des fonctionnalités réellement présentes.

Pour chacune, indique :
- Son objectif.
- Son emplacement dans le projet.
- Son état d'implémentation.
- Les dépendances nécessaires à son fonctionnement.
- Les tests ou preuves disponibles.
- Les défauts constatés.
- Les vérifications encore nécessaires.

Classe les fonctionnalités dans les catégories suivantes :

- Fonctionnelle et vérifiée.
- Implémentée mais insuffisamment vérifiée.
- Partiellement implémentée.
- Simulée ou utilisant des données fictives.
- Défectueuse.
- Non implémentée.
- Impossible à vérifier dans l'environnement actuel.

Vérifie les parcours de bout en bout lorsqu'ils peuvent être testés sans risque : interface, validation, appels API, traitement métier, persistance et retour utilisateur.

Pour le frontend, examine notamment les états de chargement, les erreurs, les formulaires, les validations, les états vides, les interactions, la navigation, la cohérence visuelle et l'adaptation aux écrans.

Pour le backend, examine notamment les routes, les règles métier, les validations, les réponses HTTP, les erreurs, les opérations sur les données et les permissions.

Ne déclare pas l'application fluide ou utilisable uniquement parce qu'elle compile.

## 6. PHASE 4 — API, BASE DE DONNÉES ET INTÉGRATIONS

Selon les technologies réellement présentes, vérifie :

- La cohérence des contrats API.
- Les méthodes HTTP et les codes de réponse.
- La validation des entrées.
- La gestion des erreurs et des réponses inattendues.
- L'authentification et les autorisations.
- La cohérence des modèles et des relations.
- Les contraintes d'intégrité.
- Les migrations et leur état.
- Les risques de perte ou de corruption de données.
- Les transactions lorsqu'elles sont nécessaires.
- Les requêtes coûteuses et les problèmes de performance identifiables.
- Les intégrations externes.
- Les délais d'attente, les erreurs réseau et les stratégies de reprise.
- Les éventuels mécanismes de limitation des requêtes.
- La configuration des environnements de développement, de test et de production.

Ne prétends pas qu'une intégration fonctionne si elle n'a pas été testée avec une configuration valide.

Ne lance aucune migration ni aucune opération d'écriture sur une base de données de production.

## 7. PHASE 5 — AUDIT DE SÉCURITÉ

Effectue une revue de sécurité proportionnée aux technologies et aux fonctionnalités du projet.

Recherche notamment :

- Secrets ou clés sensibles exposés dans le code, l'historique Git ou les fichiers de configuration accessibles.
- Risques d'accès non autorisé.
- Mauvaise gestion des rôles et des permissions.
- Défauts de validation et de nettoyage des entrées.
- Risques d'injection.
- Contrôles insuffisants sur les ressources demandées par les utilisateurs.
- Mauvaise configuration CORS, CSRF ou des cookies, lorsque ces mécanismes s'appliquent.
- Problèmes de gestion des sessions et des jetons.
- Dépendances présentant des vulnérabilités connues, si un outil ou une source fiable permet de les vérifier.
- Exposition excessive d'informations dans les erreurs et les journaux.
- Configurations dangereuses pour la production.
- Absence de protections pertinentes pour les fonctionnalités réellement présentes.

Distingue les vulnérabilités confirmées des risques théoriques.

N'affiche jamais la valeur d'un secret. Indique uniquement son emplacement, sa nature et la mesure corrective recommandée.

Ne considère pas un scan sans résultat comme une garantie d'absence de vulnérabilité.

## 8. PHASE 6 — TESTS ET FIABILITÉ

Identifie les outils et les tests réellement configurés dans le projet.

Examine, selon ce qui existe :

- Tests unitaires.
- Tests d'intégration.
- Tests API.
- Tests de composants.
- Tests de bout en bout.
- Vérifications de types.
- Analyse statique.
- Lint.
- Compilation ou build de production.
- Tests de migrations.
- Tests de permissions.
- Tests des principaux scénarios d'erreur.

Exécute les vérifications non destructives qui peuvent être réalisées dans l'environnement disponible, en respectant les contraintes de préservation du projet.

Avant d'exécuter une commande, vérifie sa nature, ses effets possibles et les prérequis.

Pour chaque test, indique :
- La commande exacte.
- Le résultat observé.
- Le nombre de tests réussis ou échoués, si disponible.
- Les erreurs pertinentes.
- Les limites de l'exécution.

Si les tests ne peuvent pas être exécutés, explique exactement pourquoi.

N'invente aucun résultat. Ne transforme pas un test non exécuté en test réussi.

## 9. PHASE 7 — DÉPENDANCES ET CHAÎNE DE LIVRAISON

Analyse :

- Les fichiers de verrouillage des dépendances.
- La cohérence des versions.
- Les dépendances inutilisées ou redondantes, si leur inutilité est démontrable.
- Les scripts de démarrage et de build.
- Les variables d'environnement requises.
- Les fichiers nécessaires au déploiement.
- Les workflows CI/CD existants.
- Les vérifications automatiques avant fusion.
- Les migrations et leur procédure de déploiement.
- Les stratégies de sauvegarde et de restauration, lorsqu'elles sont documentées.
- La gestion des logs et des erreurs.
- Les contrôles de santé de l'application, lorsqu'ils sont pertinents.
- Les possibilités de retour à une version stable en cas d'échec.

Ne considère pas une fonctionnalité DevOps comme absente sans avoir inspecté les fichiers et les outils pertinents.

## 10. PHASE 8 — PRÉPARATION À LA PRODUCTION

Évalue objectivement si le projet est prêt à être utilisé par de vrais utilisateurs.

Vérifie les éléments pertinents parmi les suivants :

- Build de production.
- Configuration de production.
- Sécurité et confidentialité.
- Gestion des erreurs.
- Persistance des données.
- Performance.
- Accessibilité et utilisabilité.
- Compatibilité des environnements.
- Fiabilité des intégrations.
- Observabilité et journalisation.
- Sauvegarde et restauration.
- Gestion des migrations.
- Disponibilité et récupération après incident.
- Capacité à supporter la charge attendue, dans la mesure où des preuves existent.
- Documentation d'installation, d'exploitation et de déploiement.

Pour chaque point, distingue :
1. Vérifié.
2. Partiellement vérifié.
3. Non vérifié.
4. Non applicable.

Ne déclare jamais le projet prêt pour la production uniquement parce que le serveur démarre ou que le build réussit.

Ne prétends pas avoir mesuré les performances, la charge ou la disponibilité sans mesures réelles.

## 11. PHASE 9 — PRÉPARATION À LA FUSION VERS MAIN

C'est une partie essentielle de l'audit.

Vérifie :
- Les changements apportés par rapport à `main`.
- Les risques de régression.
- Les conflits de fusion potentiels.
- La cohérence de la branche cible.
- Les tests nécessaires avant fusion.
- Les migrations ou changements incompatibles.
- Les modifications de configuration.
- Les éventuelles modifications accidentelles de fichiers.
- Les exigences de CI/CD et de protection de branche accessibles.

Si possible, évalue la possibilité d'une fusion sans effectuer la fusion elle-même.

Ne lance aucune fusion, aucun rebase, aucun push et aucune modification de l'historique Git.

Termine cette phase par un verdict explicite :

- **GO** : les conditions de fusion définies par l'audit sont satisfaites.
- **GO SOUS CONDITIONS** : la fusion n'est envisageable qu'après les corrections ou validations précisées.
- **NO-GO** : des problèmes bloquants ou des incertitudes critiques empêchent de recommander la fusion.

Le verdict doit être justifié par des preuves, et non par une impression générale.

Distingue impérativement :
- L'autorisation technique de fusionner.
- L'autorisation de déployer en production.

Une branche peut être fusionnable sans que l'application soit prête pour la production.

## 12. PHASE 10 — PLAN DE CORRECTION

À la fin de l'audit, établis un plan de correction priorisé.

Pour chaque problème, fournis :
- Un identifiant unique.
- Une description précise.
- Le fichier ou le composant concerné.
- La preuve.
- Le niveau de gravité.
- Le risque pour la fusion.
- Le risque pour la production.
- La correction recommandée.
- Les tests qui devront confirmer la correction.

Utilise les niveaux suivants :

- **P0 — Critique :** risque majeur pour la sécurité, l'intégrité des données ou le fonctionnement essentiel.
- **P1 — Élevé :** défaut majeur ou risque important avant fusion ou production.
- **P2 — Moyen :** défaut significatif à corriger selon sa priorité.
- **P3 — Faible :** amélioration non bloquante.

Ne classe pas arbitrairement tous les problèmes en critiques.

Sépare les corrections obligatoires avant fusion, celles obligatoires avant production et les améliorations pouvant attendre.

Ne recommande pas de corriger immédiatement tous les problèmes sans distinction : donne un ordre d'exécution logique et justifié.

## 13. FORMAT DU RAPPORT FINAL

Présente un rapport professionnel, précis, lisible et directement exploitable, dans cet ordre :

### 1. Verdict exécutif
- État global réel.
- Verdict de fusion : GO, GO SOUS CONDITIONS ou NO-GO.
- Verdict de mise en production.
- Principaux risques.
- Niveau de confiance de l'audit et limites de couverture.

### 2. État Git et dépôt GitHub
- Branche actuelle.
- Branche cible.
- État des modifications locales.
- Différences de commits.
- Conflits et risques de fusion.
- Informations distantes réellement vérifiées.

### 3. Santé technique du projet
Évalue séparément :
- Architecture.
- Qualité du code.
- Fonctionnalités.
- Frontend.
- Backend.
- API.
- Base de données.
- Sécurité.
- Tests.
- Dépendances.
- CI/CD.
- Performance.
- Maintenabilité.
- Préparation à la production.

Pour chaque domaine, donne un statut, les preuves disponibles, les défauts constatés et les limites de vérification.

Si tu utilises une note sur 100, explique la méthode de calcul et ne donne pas une précision que les preuves ne permettent pas.

### 4. Tableau des problèmes
Présente les problèmes identifiés avec leur priorité, leurs preuves, leurs conséquences et les corrections recommandées.

### 5. Fonctionnalités vérifiées
Indique ce qui fonctionne réellement, ce qui fonctionne partiellement, ce qui est simulé et ce qui reste à tester.

### 6. Tests exécutés
Liste les commandes réellement lancées, les résultats et les tests non exécutés.

### 7. Risques avant fusion
Liste les bloqueurs et les validations encore nécessaires.

### 8. Risques avant production
Liste les défauts qui empêchent ou fragilisent un déploiement réel.

### 9. Plan de correction priorisé
Donne un ordre de traitement concret, du plus critique au moins urgent.

### 10. Checklist finale de validation
Fournis une checklist vérifiable des conditions à remplir avant fusion, puis une checklist distincte avant déploiement.

### 11. Décision finale
Termine par une conclusion sans ambiguïté :
- Peut-on fusionner maintenant ?
- Si non, quels éléments précis bloquent ?
- Que faut-il corriger en premier ?
- Quelles preuves permettront de valider les corrections ?
- Peut-on envisager la production après ces corrections ou reste-t-il des validations indispensables ?

## 14. MODE D'EXÉCUTION

Travaille de manière méthodique et autonome, sans me demander de confirmer chaque petite étape.

Commence par l'inspection en lecture seule, puis effectue uniquement les vérifications non destructives que l'environnement permet.

Si le projet est volumineux, avance par phases et conserve une trace des fichiers inspectés, des commandes exécutées et des points restant à vérifier.

Ne te contente pas de lire quelques fichiers centraux et de conclure sur l'ensemble du projet.

Ne modifie pas le code pour masquer les problèmes découverts.

Ne crée pas de fichiers de rapport dans le dépôt pendant la phase d'inspection, sauf autorisation préalable.

Si une limite technique empêche un contrôle, explique-la et propose la manière la plus sûre de compléter l'audit.

**IMPORTANT : À ce stade, je te demande un AUDIT, pas une correction automatique. Tu dois terminer le diagnostic, fournir le rapport et attendre mon autorisation explicite avant de modifier le code ou d'effectuer une opération Git.**

La priorité absolue est la fiabilité du diagnostic, la protection du dépôt et la préparation d'une fusion maîtrisée vers `main`, suivie d'une mise en production sécurisée.