# CHAPITRE II : CONTEXTE DE L'ÉTUDE

## Section 1 : Contexte général

### Sous-section 1 : L'importance du secteur agricole dans l'économie sénégalaise

L'agriculture sénégalaise combine une agriculture pluviale, dominante dans le Bassin arachidier et en Casamance (mil, sorgho, maïs, arachide, niébé), une agriculture irriguée dans la vallée du fleuve Sénégal (riz, tomate industrielle, oignon) et un maraîchage périurbain très actif dans la zone des Niayes (oignon, pomme de terre, chou, carotte, piment). Cette diversité se retrouve dans les fiches agronomiques de Naatal Agro, qui couvrent des céréales, des légumineuses, des légumes et un fruit.

Les chiffres macroéconomiques de référence sont rappelés dans l'introduction : le secteur contribue pour une part significative au produit intérieur brut et occupe une proportion importante de la population active, avec des écarts selon les sources. [À COMPLÉTER : un tableau de chiffres clés (production céréalière, superficies, nombre d'exploitations) tiré des publications du ministère de l'Agriculture, de l'ANSD et de la FAO, avec année et source pour chaque ligne.] Les politiques publiques récentes (Plan Sénégal émergent, programmes de relance agricole) font de la modernisation de l'agriculture une priorité ; la numérisation des services au producteur en est l'un des leviers. [À COMPLÉTER : citer le document de politique agricole précis et sa période.]

### Sous-section 2 : Les défis majeurs : accès à l'information et aux marchés

Quatre défis structurent le besoin auquel répond le projet :

1. **L'accès à une information agronomique fiable et à jour.** Les itinéraires techniques existent dans des documents de recherche ou de vulgarisation, souvent anciens : plusieurs de nos fiches reposent sur un bilan de la recherche agricole publié en 2005, ce qui nous oblige à signaler que les variétés et doses doivent être confirmées auprès d'un conseiller.
2. **La connaissance des prix.** Sans information sur les prix pratiqués sur les différents marchés, le producteur négocie en position de faiblesse.
3. **Les aléas climatiques.** Le calendrier cultural dépend de pluies irrégulières ; une prévision locale peut décider de la date de semis.
4. **Les risques sanitaires des cultures.** Le choix d'un traitement (produit, dose, moment) est une décision à risque pour la récolte, la santé et l'environnement.

À ces défis s'ajoute une contrainte technique : une connexion souvent intermittente en zone rurale.

## Section 2 : Contexte spécifique (le projet Naatal Agro)

### Sous-section 1 : Genèse et objectifs de la plateforme Naatal Agro

[À COMPLÉTER : expliquer l'origine et le sens du nom « Naatal Agro », tel que vous le donnez vous-même.] Le projet est né du constat qu'un producteur dispose rarement, au même endroit, de son suivi de culture, de ses comptes, de l'état de son stock, des prix et d'un conseil agronomique fiable. Naatal Agro vise à réunir ces services dans une application mobile simple, avec un assistant conversationnel au centre.

La vision initiale du projet était plus large (marketplace, acheteurs, paiements). Pour tenir la qualité dans le temps imparti d'un projet de fin de formation, nous avons **recentré la première version sur le producteur** et retiré le module B2B ainsi que l'interface web, reportés à des phases ultérieures. Ce recentrage est un choix de méthode : mieux vaut un périmètre plus étroit, réellement testé, qu'une large promesse non tenue.

Les fonctionnalités de la première version sont :

- **Compte et profil** : inscription, connexion par numéro de téléphone, changement de mot de passe, modification du profil, droits sur les données (politique de confidentialité, export, suppression du compte).
- **Suivi des cultures** : création de parcelles, activités (semis, irrigation, traitement, récolte), signalement de maladies ou de ravageurs, calendrier.
- **Finances** : transactions de recette et de dépense, ventes par culture, résumé financier.
- **Stocks** : produits stockés, quantités, alertes.
- **Marchés** : liste des marchés, prix par produit, tendances, carte.
- **Météo** : conditions et prévisions locales.
- **Notifications** : rappels et alertes dans l'application.
- **Assistant Naatal IA** : conseils agronomiques sourcés en conversation, analyse d'une photo de plante.

### Sous-section 2 : Public cible et attentes des utilisateurs

Le public cible de la première version est le **producteur sénégalais**, qu'il soit céréalier, maraîcher ou arboriculteur. Ses attentes, déduites du contexte, sont : rapidité (peu de clics), lisibilité (grandes cibles tactiles, textes clairs, français simple), fiabilité (ne pas être induit en erreur), et utilité immédiate (une réponse à la question du moment). Des utilisateurs secondaires (coopératives, conseillers, acheteurs) sont envisagés à moyen terme, mais n'ont pas guidé les choix de la première version.

[À COMPLÉTER SI POSSIBLE : si vous avez échangé avec des producteurs ou des conseillers agricoles, résumer ici ces échanges (nombre de personnes, lieu, date, questions posées, enseignements). Ne rien écrire que vous n'ayez réellement recueilli ; à défaut, indiquer que le besoin a été établi par l'analyse documentaire et que la validation terrain est une perspective.]

---

# CHAPITRE III : CADRE MÉTHODOLOGIQUE ET CONCEPTION

## Section 1 : Spécification et modélisation du système

### Sous-section 1 : Spécification des besoins fonctionnels et non fonctionnels

**Besoins fonctionnels.**

| Code | Besoin | Priorité |
|---|---|---|
| BF1 | Créer un compte, se connecter, se déconnecter, changer son mot de passe | Haute |
| BF2 | Créer, consulter, modifier et supprimer ses cultures et leurs activités | Haute |
| BF3 | Signaler une maladie ou un ravageur | Moyenne |
| BF4 | Enregistrer ses recettes, dépenses et ventes ; consulter un résumé financier | Haute |
| BF5 | Suivre ses stocks et être alerté d'un niveau bas | Moyenne |
| BF6 | Consulter les marchés, les prix et leurs tendances | Haute |
| BF7 | Consulter la météo locale | Moyenne |
| BF8 | Poser des questions à l'assistant et recevoir une réponse sourcée ; envoyer une photo | Haute |
| BF9 | Consulter l'historique de ses échanges avec l'assistant | Moyenne |
| BF10 | Exporter ses données et supprimer son compte | Haute (légal) |
| BF11 | Recevoir des notifications dans l'application | Moyenne |
| BF12 | Pour l'administration : alimenter et valider les fiches agronomiques et les propositions de connaissance | Haute |

**Besoins non fonctionnels.**

| Code | Besoin | Mesure retenue |
|---|---|---|
| BNF1 | **Sécurité** : isolation des données par utilisateur, authentification robuste, limitation des abus | Tests d'accès croisé ; limites de débit (10 tentatives de connexion par minute, 30 questions IA par heure) |
| BNF2 | **Fiabilité de l'assistant** : sources obligatoires, aveu d'ignorance | Tests de traçabilité des fiches et des citations |
| BNF3 | **Performance** : nombre de requêtes SQL indépendant du volume de données, listes paginées | Test automatique de comptage de requêtes (N+1), mesure des temps de réponse |
| BNF4 | **Résilience** : aucune action perdue sans réseau ; lecture hors ligne | Tests de la file d'attente et du cache |
| BNF5 | **Utilisabilité** : interface simple, textes courts, cibles tactiles suffisantes | Principes de conception ; validation terrain prévue |
| BNF6 | **Maintenabilité** : code structuré, tests, intégration continue | Analyse statique sans alerte, tests exécutés à chaque modification |
| BNF7 | **Protection des données personnelles** | Politique, consentement, export, suppression |

### Sous-section 2 : Étude et choix des méthodes de modélisation

Nous avons retenu **UML** pour sa lisibilité par des lecteurs non spécialistes et son adéquation à une application orientée objet. Trois vues ont été produites :

- les **cas d'utilisation**, pour délimiter le périmètre et identifier les acteurs (producteur, administrateur, services externes d'intelligence artificielle et de météo) ;
- les **diagrammes de classes**, séparés en classes de données et classes de services, pour structurer le domaine ;
- les **diagrammes de séquence**, pour les échanges critiques : connexion, question à l'assistant, validation d'une fiche.

La conception de la base de données suit le principe d'une **architecture par domaines** : chaque domaine (utilisateurs, agriculture, finances, stocks, marchés, météo, notifications, assistant) est un module du backend avec ses modèles, ses sérialiseurs, ses vues et ses tests. Cette organisation limite le couplage et facilite les tests.

### Sous-section 3 : Modélisation

[Insérer ici les figures, qui existent dans le dépôt, dossier `docs/uml/` :
Figure 1 : diagramme des cas d'utilisation (`01-use-case.png`) ;
Figure 2 : diagramme de classes, données (`02a-diagramme-classes-donnees.png`) ;
Figure 3 : diagramme de classes, services (`02b-diagramme-classes-services.png`) ;
Figure 4 : séquence de connexion (`03a-sequence-connexion.png`) ;
Figure 5 : séquence d'une question à l'assistant (`03b-sequence-assistant.png`) ;
Figure 6 : séquence de validation d'une fiche (`03c-sequence-validation-fiche.png`).]

**Acteurs.** Le *producteur* utilise l'application. L'*administrateur* gère les fiches agronomiques et valide les propositions de connaissance. Deux *services externes* interviennent : les fournisseurs de modèles de langage (Gemini, Groq) et le service de météo.

**Modèle de données.** Les entités principales sont :

| Domaine | Entité | Rôle | Attributs principaux |
|---|---|---|---|
| Utilisateurs | User | Compte du producteur | téléphone (identifiant), localisation, langue, cultures principales, version de politique acceptée et date de consentement |
| Agriculture | Crop | Parcelle cultivée | propriétaire, nom, type de culture, dates de semis et de récolte prévue, statut, surface, localisation |
| Agriculture | Activity | Opération sur une culture | culture, type, description, date, coût |
| Agriculture | PestReport | Signalement de maladie ou de ravageur | auteur, nom, lieu, date, description |
| Agriculture | AgronomicGuide | Fiche agronomique | culture, noms alternatifs, résumé, zones, calendrier, sol et semis, eau, fertilisation, maladies et ravageurs, récolte, rendement, limites, **sources** |
| Agriculture | KnowledgeProposal | Proposition de mise à jour d'une fiche, en attente de validation humaine | fiche visée, champ, texte proposé, citation, source, statut, relecteur |
| Finances | Transaction | Recette ou dépense | propriétaire, type, montant, date, description |
| Finances | Sale | Vente d'une culture | culture, quantité, prix unitaire, date, acheteur |
| Stocks | StockItem | Produit stocké | propriétaire, nom, quantité, unité, alerte |
| Marchés | Market, Price, Product | Marchés, prix relevés et produits suivis | nom, région, prix, tendance, date |
| Météo | WeatherData | Conditions et prévisions | lieu, température, humidité, pluie, date |
| Notifications | Notification | Message adressé à un utilisateur | type, message, lu ou non |
| Assistant | AIInteraction | Un échange avec l'assistant | question, réponse, **origine** (fiches ou conseil général), **sources**, **questions suggérées**, date |

Tous les identifiants sont des UUID, ce qui empêche de deviner l'identifiant d'une ressource voisine. Les ressources privées (cultures, activités, transactions, ventes, stocks, notifications, échanges avec l'assistant) portent un lien vers leur propriétaire, directement ou par l'intermédiaire de la culture ; l'accès est filtré sur cet attribut dans chaque vue. Les données de référence (marchés, prix, produits, météo, fiches) sont communes à tous.

## Section 2 : Implémentation et évaluation des modèles

### Sous-section 1 : Choix technologiques et justification

| Couche | Technologie | Justification |
|---|---|---|
| Application mobile | **Flutter** (Dart), Riverpod, go_router, Dio | Un seul code pour Android et iOS ; écosystème mûr ; gestion d'état réactive adaptée à l'offline |
| Stockage sécurisé | flutter_secure_storage | Les jetons ne sont jamais stockés en clair |
| Backend | **Django 5** et **Django REST Framework** | Productivité, ORM robuste, interface d'administration utile pour gérer les fiches |
| Authentification | **SimpleJWT** (rotation et liste noire des jetons) | Jetons courts, invalidation à la déconnexion |
| Base de données | **SQLite** en développement, **PostgreSQL** prévu en production | Simplicité pendant le développement ; robustesse et concurrence en production |
| Assistant | **Gemini** et **Groq**, avec bascule | Deux fournisseurs pour la disponibilité ; l'assistant fonctionne même sans eux (réponse depuis les fiches) |
| Conteneurs | Docker, nginx | Reproductibilité du déploiement |
| Qualité | GitHub Actions, tests Django et Flutter, analyse statique | Chaque modification est testée automatiquement |

Un choix assumé : la **base de données reste SQLite jusqu'à la fin du développement**, la bascule vers PostgreSQL étant faite au déploiement, pour ne pas disperser l'effort ; les requêtes ont été écrites avec l'ORM, donc indépendamment du moteur.

### Sous-section 2 : Description de l'expérimentation

Faute de déploiement auprès de producteurs au moment de la rédaction, l'évaluation porte sur la **qualité technique mesurable** du système et non sur l'adoption. Quatre dispositifs ont été mis en œuvre :

1. **Tests automatisés du serveur** (203 tests à la date de rédaction) : authentification, isolation des données, droits sur les données personnelles, fiches agronomiques, assistant (recherche, citations, aveu d'ignorance, mémoire de conversation, questions suggérées), performance.
2. **Tests automatisés de l'application mobile** (41 tests) : jetons et rafraîchissement, file d'attente hors ligne, pagination, déconnexion, lecture des montants, parcours d'entrée.
3. **Mesure de performance** : un test appelle chaque point d'accès avec 3 puis 30 éléments par type de donnée et vérifie que le nombre de requêtes SQL ne grandit pas (détection des requêtes « N+1 ») ; un rapport mesure aussi les temps de réponse avec 300 cultures.
4. **Revues de code et audits** : une revue de sécurité a identifié et fait corriger des failles avant qu'elles ne soient exploitées ; la méthode est décrite au chapitre IV.

**Protocole de validation terrain prévu (perspective).** Pour éprouver l'hypothèse H2 (utilité des réponses courtes) : [À COMPLÉTER SI RÉALISÉ, sinon le laisser comme protocole] échantillon de 5 à 10 producteurs ou conseillers ; tâches à réaliser (ajouter une culture, poser une question à l'assistant, consulter un prix) ; mesures : taux de réussite, temps par tâche, compréhension des réponses, satisfaction (échelle de 1 à 5) ; recueil des remarques. Aucun résultat n'est présenté ici tant que ce protocole n'a pas été exécuté.
