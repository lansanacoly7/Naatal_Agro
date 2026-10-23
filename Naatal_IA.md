# MISSION : CONSTRUIRE NAATAL IA, L'ASSISTANT INTELLIGENT DE NAATAL AGRO

## 1. Ton rôle

Tu agis comme un architecte logiciel senior, un ingénieur IA, un développeur full-stack expérimenté et un expert UX/UI.

Ta mission est de concevoir et d'implémenter **Naatal IA**, l'assistant intelligent central de Naatal Agro.

Ce projet ne consiste pas simplement à intégrer une API de modèle de langage dans une interface de chat. Nous voulons construire un véritable assistant agricole et commercial, capable de comprendre les besoins de l'utilisateur, de consulter ses données réelles, de tenir une conversation naturelle, d'effectuer des actions autorisées et de l'aider à prendre de meilleures décisions.

**Règle absolue : tu dois travailler étape par étape. Tu ne dois jamais essayer d'implémenter toutes les fonctionnalités en une seule fois.**

---

## 2. Vision du produit

Naatal IA doit devenir le compagnon intelligent de l'utilisateur dans la gestion de son activité agricole.

L'utilisateur doit pouvoir lui parler comme à une personne compétente, lui poser des questions simples ou complexes, demander des analyses, obtenir des recommandations et effectuer des opérations sans avoir à chercher manuellement chaque fonctionnalité dans l'application.

Exemples de demandes :

- « Combien j'ai gagné depuis le début de la saison ? »
- « Quel produit m'a rapporté le plus d'argent ? »
- « Quels produits se vendent le mieux chez moi ? »
- « Combien me reste-t-il de sacs de mil ? »
- « Enregistre une dépense de 15 000 FCFA pour l'achat d'engrais. »
- « Rappelle-moi d'arroser mes cultures demain matin. »
- « Quels produits dois-je acheter en priorité ? »
- « Est-ce que je devrais investir dans davantage de tomates ou d'oignons ? »
- « Pourquoi mes dépenses augmentent-elles ? »
- « Fais-moi un résumé de mon activité cette semaine. »
- « J'ai vendu une partie de ma récolte. Aide-moi à mettre mes informations à jour. »

L'assistant doit comprendre l'intention derrière chaque demande, identifier les informations nécessaires, consulter les données pertinentes et proposer une réponse adaptée.

## 3. Phase obligatoire : audit de l'existant

Avant toute modification, examine intégralement les parties pertinentes du projet.

Analyse notamment :

- L'architecture générale et les technologies déjà utilisées.
- Le frontend Flutter et l'interface actuelle de Naatal IA.
- Le backend Django et Django REST Framework.
- Les modèles de données, les relations et les migrations.
- Les API existantes et leur documentation.
- Le système d'authentification, les rôles et les permissions.
- Les fonctionnalités de production, ventes, dépenses, revenus, stocks, cultures, marchés et alertes.
- Les éventuelles intégrations IA déjà présentes, notamment Gemini ou Groq.
- La gestion des erreurs, les tests, la configuration et les secrets.
- Les éventuelles fonctionnalités partiellement développées ou simulées.

Ne suppose jamais qu'une fonctionnalité existe simplement parce qu'un bouton ou un écran est présent.

Identifie précisément ce qui fonctionne, ce qui est incomplet, ce qui est simulé et ce qui manque.

Produis un diagnostic technique comprenant :
1. L'architecture actuelle.
2. Les fonctionnalités réutilisables.
3. Les problèmes et les risques.
4. Les éléments manquants pour réaliser la vision.
5. Le plan d'implémentation classé par priorité.
6. Les critères permettant de valider chaque phase.

**À cette première étape, ne modifie aucun fichier.** Présente ton audit et attends ma validation avant de commencer l'implémentation.

---

## 4. Les capacités attendues de Naatal IA

### A. Une conversation réellement intelligente

L'assistant doit pouvoir tenir une conversation sur plusieurs messages.

Il doit :
- Comprendre les questions courtes, les formulations imprécises et les demandes exprimées naturellement.
- Conserver le contexte utile de la conversation.
- Comprendre les références comme « ce produit », « mes dernières ventes » ou « cette dépense » en utilisant le contexte disponible.
- Poser une question lorsque des informations essentielles manquent.
- Éviter de demander une information déjà disponible et fiable.
- Reconnaître les ambiguïtés et demander une précision au lieu de deviner.
- Répondre directement lorsque la demande est simple.
- Développer ses explications lorsque la question exige une véritable analyse.
- Fournir des résumés lorsque cela est plus utile qu'une longue réponse.
- Savoir reconnaître ses limites et signaler les incertitudes.

La personnalité doit être chaleureuse, naturelle, professionnelle, calme, encourageante et accessible. L'assistant ne doit pas paraître robotique ni réciter systématiquement de longues explications.

Il doit être un conseiller fiable, pas un assistant qui approuve automatiquement toutes les décisions de l'utilisateur.

### B. Une compréhension réelle des données métier

Naatal IA doit pouvoir accéder, avec les permissions appropriées, aux données réelles du compte connecté.

Les domaines concernés comprennent :
- Les exploitations et les parcelles.
- Les cultures et les cycles de production.
- Les récoltes et les quantités produites.
- Les ventes, les prix et les recettes.
- Les dépenses et les coûts de production.
- Les stocks et leurs mouvements.
- Les pertes, les invendus et les produits détériorés lorsqu'ils sont suivis.
- Les fournisseurs et les clients, selon les fonctionnalités existantes.
- Les tâches, les rappels et les alertes.
- Les données de marché et les prix disponibles.
- Les historiques permettant d'analyser l'évolution de l'activité.

L'assistant doit répondre exclusivement à partir des données réellement disponibles pour les analyses propres à l'utilisateur.

Il doit notamment pouvoir calculer :
- Les recettes totales sur une période.
- Les dépenses totales.
- Le résultat financier estimé.
- Les produits générant les recettes les plus élevées.
- Les produits les plus rentables lorsque les coûts correspondants sont connus.
- L'évolution des ventes et des dépenses.
- Les stocks disponibles et les risques de rupture.
- Les écarts entre les résultats de plusieurs périodes.

Ne confonds jamais chiffre d'affaires, bénéfice, marge et trésorerie.

Précise la période, les unités, les hypothèses et les éventuelles données manquantes. Distingue les chiffres calculés à partir des enregistrements réels des estimations.

N'invente jamais de chiffres pour donner une réponse apparemment convaincante.

### C. Un assistant capable d'effectuer des actions

Naatal IA ne doit pas uniquement expliquer comment utiliser l'application. Il doit pouvoir déclencher certaines opérations métier via des outils sécurisés connectés aux API existantes.

Actions à prendre en charge progressivement :
- Enregistrer une dépense.
- Enregistrer une vente ou une recette.
- Ajouter ou corriger une information de stock.
- Consulter l'historique des mouvements.
- Créer, consulter, modifier ou annuler une alerte.
- Programmer un rappel.
- Consulter les informations d'une culture ou d'une parcelle.
- Préparer un résumé d'activité.
- Guider l'utilisateur dans une opération plus complexe.

Exemple :

Utilisateur : « J'ai dépensé 15 000 FCFA pour de l'engrais. »

Naatal IA doit vérifier les informations nécessaires, identifier la catégorie appropriée si possible, demander une précision si nécessaire et préparer l'enregistrement.

Avant de valider une opération financière ou une modification importante, il doit présenter un récapitulatif clair et demander confirmation.

Utilisateur : « Confirme. »

L'assistant exécute alors l'opération via le backend sécurisé, vérifie le résultat renvoyé par l'API et confirme uniquement si l'enregistrement a réellement réussi.

Il ne doit jamais prétendre avoir enregistré, modifié ou supprimé une donnée sans confirmation effective du backend.

Prévois des mécanismes contre les doubles enregistrements, les requêtes répétées et les erreurs partielles.

### D. Des analyses et des conseils personnalisés

L'assistant doit transformer les données en informations utiles à la prise de décision.

Il doit pouvoir :
- Identifier les produits qui génèrent le plus de recettes.
- Identifier les produits les plus rentables lorsque les coûts sont disponibles.
- Détecter les dépenses qui augmentent anormalement.
- Comparer les performances de différentes cultures.
- Repérer les risques de rupture de stock.
- Comparer les résultats entre deux périodes.
- Proposer des pistes pour améliorer les marges.
- Aider à planifier les achats et les ventes.
- Signaler les informations manquantes qui empêchent une bonne décision.
- Formuler des recommandations adaptées à la taille de l'exploitation et à ses objectifs.

Pour les recommandations d'investissement agricole, prendre en compte, selon les informations disponibles :
- Le coût des intrants.
- Les prix de vente observés et leur date.
- Les rendements historiques ou les estimations documentées.
- Les délais de production.
- La saisonnalité.
- La demande et les débouchés commerciaux.
- Les coûts de transport, de stockage et de commercialisation.
- Les risques climatiques, phytosanitaires et commerciaux.
- Le capital disponible et les pertes potentielles.

Présente des scénarios prudents, intermédiaires et favorables lorsque les données le permettent. Explique les hypothèses et les risques.

Ne garantis jamais un rendement, un bénéfice ou un succès commercial. Si les données sont insuffisantes, dis-le et indique les informations à collecter.

Pour les conseils agronomiques, privilégie les informations fiables, adaptées au contexte local et aux conditions de la culture. Ne présente pas une hypothèse comme un fait vérifié.

---

## 5. Français, wolof et interaction vocale

L'assistant doit pouvoir communiquer en français et en wolof.

Il doit :
- Comprendre les demandes écrites et vocales.
- Reconnaître la langue utilisée lorsque cela est techniquement possible.
- Répondre dans la langue de l'utilisateur.
- Gérer progressivement les formulations naturelles, les variantes de wolof et les mélanges français-wolof.
- Conserver le contexte lorsqu'une conversation passe d'une langue à l'autre.

Ne déclare pas le support du wolof pleinement opérationnel sans tests réels. Évalue les capacités des modèles et services disponibles et propose une solution mesurable.

### Interaction vocale

Implémente progressivement une véritable expérience vocale comprenant :

1. La capture de la voix.
2. La transcription de la parole en texte.
3. La transmission du message à l'assistant.
4. La génération de la réponse.
5. La synthèse vocale de cette réponse.
6. La lecture audio avec possibilité d'interrompre la réponse.
7. L'affichage du texte correspondant à la réponse vocale.

Étudie ensuite le streaming audio, la détection de fin de parole et les échanges vocaux plus rapides si l'architecture le permet.

La solution doit être adaptée au contexte d'utilisation agricole : connexion parfois faible, appareils mobiles, coût des services et simplicité d'utilisation.

Prévois une gestion claire des permissions du microphone, des erreurs de transcription, des délais et des interruptions.

La voix doit être naturelle et agréable, mais la fiabilité de la réponse reste prioritaire.

Évalue les coûts, la qualité en français et en wolof, les limites de chaque service et les solutions de remplacement avant de retenir une architecture.

---

## 6. Une interface Naatal IA exceptionnelle

L'interface doit être moderne, élégante, rapide, responsive et cohérente avec l'identité visuelle de Naatal Agro.

Évite l'apparence d'un simple formulaire ou d'une copie générique d'un chatbot.

L'expérience doit privilégier :
- Une conversation lisible et fluide.
- Une zone de saisie adaptée au mobile.
- Un bouton vocal facilement accessible.
- Des états de chargement clairs.
- Des suggestions de questions pertinentes.
- Des réponses structurées sans surcharge visuelle.
- Des tableaux et graphiques lorsque les chiffres le justifient.
- Des cartes de résultats pour les analyses utiles.
- Des actions contextuelles pour consulter ou modifier les données.
- Des confirmations explicites avant les opérations sensibles.
- Des erreurs compréhensibles et des possibilités de réessayer.
- Un historique de conversation organisé et pertinent.

Les premières suggestions peuvent être :
« Analyse mes revenus », « Vérifie mon stock », « Analyse mes dépenses » et « Aide-moi à préparer mes prochaines ventes ».

Elles doivent être adaptées au contexte et aux données disponibles.

L'assistant ne doit pas afficher des graphiques ou des blocs d'informations pour chaque réponse. Une question simple appelle une réponse simple.

---

## 7. Architecture technique et sécurité

Respecte l'architecture existante. Ne remplace pas arbitrairement les technologies déjà utilisées.

Si le projet conserve Flutter, Django REST Framework et PostgreSQL, exploite cette architecture plutôt que de reconstruire l'application sans nécessité.

Conçois Naatal IA avec des composants clairement séparés :
- Interface conversationnelle.
- Gestion des conversations et de leur contexte.
- Orchestration du modèle d'IA.
- Outils métier disponibles pour l'assistant.
- Services d'accès aux données.
- Couche de calcul et d'analyse.
- Services vocaux.
- Système de vérification et d'autorisation des actions.
- Gestion des erreurs, des journaux techniques et des coûts.

Le modèle d'IA ne doit pas disposer d'un accès direct et illimité à la base de données.

Toutes les opérations passent par des services métier et des API contrôlées. Les permissions doivent être vérifiées côté serveur pour chaque requête.

Exigences :
- Isolation stricte des données entre utilisateurs.
- Authentification et autorisation systématiques.
- Validation des entrées.
- Protection contre les injections de prompt et les instructions malveillantes contenues dans les données récupérées.
- Clés API stockées dans des variables d'environnement ou un gestionnaire de secrets.
- Aucune clé secrète dans le frontend.
- Limites de requêtes, gestion des délais et des erreurs.
- Protection des données personnelles et minimisation des données envoyées aux fournisseurs d'IA.
- Journalisation sans exposition inutile d'informations sensibles.
- Gestion des coûts et des quotas.
- Tests des permissions, des erreurs et des opérations financières.
- Possibilité de changer de fournisseur de modèle sans réécrire toute l'application.

Les actions métier doivent être explicitement définies, validées et autorisées. L'assistant ne doit pas pouvoir contourner les règles de l'application.

---

## 8. Gestion du contexte et fiabilité

L'assistant doit disposer d'un contexte de conversation utile, sans charger systématiquement tout l'historique ni toutes les données de l'exploitation.

Il doit récupérer uniquement les informations pertinentes pour la question posée, avec des dates et des sources clairement identifiées.

Sépare :
- Le contexte de la conversation en cours.
- Les informations métier issues de la base de données.
- Les connaissances agricoles externes.
- Les calculs effectués par les services métier.
- Les estimations et les recommandations du modèle.

Les calculs financiers importants doivent être réalisés et vérifiés par du code déterministe, pas laissés à la seule estimation du modèle de langage.

Pour les connaissances externes, notamment les prix de marché, la météo et les conseils agricoles, utilise des sources fiables lorsque des intégrations adaptées sont disponibles. Affiche la date, la provenance et les limites des informations.

Si une source n'est pas accessible ou si une donnée n'est pas connue, explique-le clairement.

---

## 9. Plan d'implémentation obligatoire

Tu dois organiser le travail en phases indépendantes, testables et validables.

### Phase 0 — Audit et planification
Analyser l'existant, établir le diagnostic et proposer le plan. Aucun changement de code.

### Phase 1 — Fondations techniques
Définir l'architecture de Naatal IA, les contrats API, la gestion des conversations, les règles de sécurité et les tests de base.

### Phase 2 — Assistant conversationnel
Mettre en place une conversation fonctionnelle, le contexte des messages, la gestion des erreurs et des réponses adaptées à la longueur de la demande.

### Phase 3 — Connexion aux données réelles
Connecter l'assistant aux données autorisées de l'utilisateur. Commencer par les consultations et les analyses en lecture seule.

### Phase 4 — Calculs et analyses métier
Implémenter les calculs fiables de recettes, dépenses, résultats financiers, ventes et stocks. Ajouter des analyses explicables et vérifiables.

### Phase 5 — Actions métier sécurisées
Permettre l'enregistrement des dépenses, ventes et autres opérations prioritaires, avec validation, confirmation et vérification du résultat.

### Phase 6 — Alertes et recommandations
Connecter les alertes, les rappels et les recommandations agricoles et commerciales aux données disponibles.

### Phase 7 — Français et wolof
Évaluer et intégrer les capacités multilingues, avec des tests réels de compréhension et de génération.

### Phase 8 — Interaction vocale
Ajouter la transcription, la synthèse vocale, les contrôles audio et les améliorations possibles pour une conversation plus naturelle.

### Phase 9 — Optimisation UX/UI
Finaliser l'interface, les états de chargement, les résultats structurés, les interactions et l'expérience mobile.

### Phase 10 — Tests et préparation à la production
Vérifier la sécurité, la fiabilité des réponses, les permissions, les performances, les coûts, la gestion des erreurs et le comportement en connexion faible.

Ces phases constituent une feuille de route, pas une obligation de créer dix systèmes isolés. Si l'audit montre qu'un composant existe déjà, réutilise-le et démontre qu'il fonctionne.

**Après chaque phase :**
1. Présente les modifications réalisées.
2. Indique les fichiers créés ou modifiés.
3. Explique les choix techniques importants.
4. Exécute les tests appropriés.
5. Présente les résultats réels des tests.
6. Signale les limites et les problèmes restants.
7. Indique la prochaine phase et ses prérequis.
8. Attends ma validation explicite avant de commencer la phase suivante.

Ne marque jamais une fonctionnalité comme terminée si elle est seulement simulée ou partiellement fonctionnelle.

Ne supprime pas de fonctionnalités existantes et ne modifie pas des parties sans rapport avec Naatal IA sans justification et validation.

---


## 10. Critères de réussite

Naatal IA sera considéré comme réellement fonctionnel lorsque les tests démontreront notamment que :

- Il répond correctement à une question simple sans produire un long texte inutile.
- Il sait approfondir une analyse complexe.
- Il consulte les bonnes données du compte connecté.
- Il calcule correctement les recettes, dépenses et résultats.
- Il distingue les recettes du bénéfice réel.
- Il ne révèle jamais les données d'un autre utilisateur.
- Il sait demander des précisions lorsqu'une demande est ambiguë.
- Il exécute une opération uniquement après les validations requises.
- Il confirme une action uniquement après un résultat positif du backend.
- Il crée et consulte correctement les alertes.
- Il gère les erreurs réseau et les indisponibilités des services d'IA.
- Il propose des recommandations dont les hypothèses et les limites sont explicites.
- Il comprend et répond en français et en wolof dans les limites vérifiées par les tests.
- Il permet un échange vocal utilisable et compréhensible.
- Il reste maintenable, testable, sécurisé et raisonnable en coût.

## 11. Première instruction à exécuter maintenant

Commence uniquement par la **Phase 0 : audit et planification**.

Inspecte le projet réel, identifie son architecture et ses fonctionnalités existantes, puis fournis-moi un diagnostic précis et un plan de travail priorisé.

Ne code rien pour le moment. Ne crée pas de fichiers. Ne commence pas la phase suivante automatiquement.

Je validerai le diagnostic avant que tu entreprennes les premières modifications.

La priorité est de construire un assistant fiable et réellement utile, pas de multiplier les fonctionnalités sans fondations solides.
