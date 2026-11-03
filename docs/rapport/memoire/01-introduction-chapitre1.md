# Introduction générale

## 1. Contexte et justification du sujet

L'agriculture occupe une place centrale dans l'économie et dans la vie quotidienne du Sénégal. Selon une fiche de la Direction générale du Trésor reprenant les données de la Banque mondiale, le secteur agricole représentait 17,4 % du produit intérieur brut en 2023 et environ 22 % des emplois (Direction générale du Trésor, 2025). Les comptes de l'Agence nationale de la statistique et de la démographie (ANSD) situent, pour leur part, la part du secteur primaire à 16,3 % du produit intérieur brut en 2022 (ANSD, cité par AllAfrica, 2024). Ces chiffres varient selon la source et la méthode de calcul, et des estimations bien plus élevées de l'emploi agricole circulent encore, que les vérificateurs de faits jugent surestimées (Africa Check, 2024). Quelle que soit la mesure retenue, une part importante des ménages sénégalais, surtout en milieu rural, tire tout ou partie de ses revenus de la production végétale. [À VÉRIFIER AVANT DÉPÔT : confirmer ces chiffres dans les dernières publications de l'ANSD (Situation économique et sociale) et de la Banque mondiale, et citer l'année exacte de chaque donnée.]

Or le producteur prend ses décisions (quand semer, quelle quantité d'engrais apporter, comment traiter une maladie, quand et où vendre) le plus souvent à partir de son expérience et de ce que lui disent ses voisins. L'information agronomique fiable existe : elle est produite par des instituts de recherche comme l'Institut sénégalais de recherches agricoles (ISRA), par des services de conseil comme l'Agence nationale de conseil agricole et rural (ANCAR) ou la Société nationale d'aménagement et d'exploitation des terres du delta (SAED). Mais elle est dispersée, rédigée pour des spécialistes, rarement à jour et difficile d'accès au moment précis où le producteur en a besoin. De même, les prix des marchés et les prévisions météorologiques locales ne lui parviennent pas toujours à temps pour orienter une décision. Une partie importante des utilisateurs potentiels est en outre peu lettrée : une information présentée sous forme de longs textes ne leur est pas accessible.

Dans le même temps, le téléphone mobile est devenu un outil quotidien. Les rapports de l'Autorité de régulation des télécommunications et des postes (ARTP) rapportés par la presse font état d'un taux de pénétration d'internet de 112,42 % en 2024 (Osiris, 2025). Ce taux dépasse 100 % parce qu'il compte des abonnements et non des personnes : il ne signifie pas que chaque habitant dispose d'un smartphone, mais il montre que le mobile est le principal point d'accès au numérique. [À VÉRIFIER : reprendre le chiffre dans le rapport trimestriel de l'ARTP et préciser la part de la population équipée d'un smartphone.] Un smartphone peut donc devenir le point d'accès à une information agricole utile, à condition que l'application soit simple, fonctionne avec une connexion irrégulière et ne mente pas à son utilisateur.

C'est dans ce contexte que s'inscrit **Naatal Agro**, une application mobile d'aide à la décision pour les producteurs sénégalais, développée dans le cadre de notre projet de fin de formation à l'Institut Supérieur d'Enseignement Professionnel (ISEP).

## 2. Problématique

Les solutions numériques agricoles existantes se heurtent à quatre difficultés dans le contexte sénégalais. Les applications internationales de diagnostic ou de conseil, comme Plantix, sont conçues pour d'autres cultures et d'autres marchés. Les assistants fondés sur des modèles de langage répondent avec aisance mais peuvent « halluciner », c'est-à-dire produire une dose, une date ou un produit plausibles mais faux, ce qui est grave en agronomie. Beaucoup de solutions supposent une connexion permanente. Enfin, la plupart s'adressent à un utilisateur lettré, habitué aux interfaces textuelles et aux menus complexes.

La problématique de ce travail est donc la suivante :

> **Comment concevoir et réaliser une application mobile qui aide concrètement un producteur sénégalais, y compris peu lettré, à décider (cultiver, traiter, vendre) en s'appuyant sur des informations agronomiques vérifiables et sourcées, tout en restant simple, sûre et utilisable avec une connexion irrégulière ?**

## 3. Questions de recherche

**Question principale.** Comment un assistant conversationnel peut-il fournir à un producteur sénégalais des conseils agronomiques à la fois accessibles (courts, en français simple, utilisables à la voix) et fiables (sourcés, sans invention) ?

**Questions spécifiques.**

1. Quelles fonctionnalités (suivi des cultures, finances, stocks, marchés, météo, calendrier, assistant) répondent aux besoins prioritaires d'un producteur, et dans quel ordre les réaliser ?
2. Comment organiser les connaissances agronomiques pour que l'assistant s'appuie d'abord sur des fiches vérifiées et signale ce qu'il ne sait pas ?
3. Comment permettre à un assistant d'agir dans l'exploitation de l'utilisateur (créer une dépense, une activité, annuler une vente) sans risque d'action non voulue ?
4. Comment protéger les données personnelles et professionnelles de chaque utilisateur dans une application dont les ressources sont toutes privées ?
5. Comment rendre une application compréhensible par un utilisateur peu lettré et utilisable avec une connexion dégradée ?
6. Comment mesurer objectivement la qualité du produit (sécurité, performance, fiabilité) sans se fonder sur des impressions ?

## 4. Objectif général et objectifs subsidiaires

**Objectif général.** Concevoir, réaliser et évaluer Naatal Agro, une application mobile (Flutter) adossée à une interface de programmation (Django REST Framework), qui accompagne le producteur sénégalais dans le suivi de son exploitation et lui fournit des conseils agronomiques sourcés grâce à un assistant conversationnel utilisable à la voix.

**Objectifs subsidiaires.**

- O1. Spécifier les besoins du producteur et en déduire un périmètre réaliste pour une première version.
- O2. Modéliser le système (cas d'utilisation, classes, séquences, base de données, architecture).
- O3. Constituer une base de fiches agronomiques et un calendrier agricole sourcés, et les exploiter en priorité dans les réponses de l'assistant.
- O4. Concevoir une interface accessible aux utilisateurs peu lettrés : images d'abord, lecture à voix haute, saisie vocale, mode sombre.
- O5. Sécuriser l'application : authentification, isolation des données par utilisateur, limitation des abus, droits sur les données personnelles.
- O6. Assurer la résilience en connexion irrégulière : file d'attente des actions et cache de lecture.
- O7. Mettre en place une démarche qualité mesurable : tests automatisés, intégration continue, mesure de performance, audit technique.
- O8. Documenter honnêtement ce qui est réalisé, ce qui est simulé et ce qui est prévu.

## 5. Hypothèses de recherche

- **H1.** Un assistant qui répond d'abord à partir de fiches sourcées, et déclare explicitement lorsqu'une information est absente, réduit le risque de conseil erroné par rapport à un assistant qui répond librement.
- **H2.** Des réponses courtes, structurées, accompagnées de questions suggérées et d'une lecture à voix haute sont mieux adaptées à un producteur pressé ou peu lettré qu'un texte exhaustif.
- **H3.** Une confirmation explicite avant toute écriture, associée à une validation du plan d'action par le code, permet de donner de l'autonomie à l'assistant sans action non voulue.
- **H4.** Une isolation systématique des données au niveau du serveur, vérifiée par des tests d'accès croisé, suffit à empêcher qu'un utilisateur lise les données d'un autre.
- **H5.** Une file d'attente locale des écritures et un cache de lecture rendent l'application utilisable en connexion intermittente sans perte de données.

Ces hypothèses sont éprouvées par des tests automatisés et des mesures décrits au chapitre IV. Les hypothèses H2 et H5 relèvent en partie de l'expérience utilisateur et appellent une validation terrain, que nous présentons comme perspective.

## 6. Méthodologie retenue

Le projet a suivi une démarche itérative, par blocs fonctionnels, avec les principes suivants :

- **Recueil et formalisation des besoins** à partir de l'analyse du contexte, d'un benchmark de solutions existantes et de la définition d'un public cible : le producteur sénégalais, utilisateur principal de la première version.
- **Modélisation en UML** (cas d'utilisation, classes, séquences) et conception relationnelle de la base de données.
- **Développement par domaines** : un backend modulaire (utilisateurs, agriculture, finances, stocks, marchés, météo, notifications, assistant, analyses, données personnelles) et une application mobile organisée par fonctionnalités.
- **Qualité par la preuve** : chaque fonctionnalité déclarée « faite » s'appuie sur un test automatisé ou une commande reproductible ; les audits de sécurité et de performance ont donné lieu à des corrections vérifiées.
- **Gestion de version et revue** : un dépôt Git, des branches de travail, des commits par sujet et des revues de code croisées entre les deux contributeurs du projet.
- **Transparence** : un document d'état distingue ce qui est réalisé, partiel, simulé volontairement ou seulement prévu.

Le développement a été assisté par des outils d'intelligence artificielle destinés à la programmation, utilisés sous la responsabilité des auteurs, avec revue du code produit et vérification par des tests automatisés. [À COMPLÉTER : valider avec l'encadrant la formulation de cet usage et préciser le rôle exact de chaque contributeur.]

## 7. Annonce du plan

Ce mémoire comporte quatre chapitres. Le chapitre I présente le cadre théorique et conceptuel (agriculture numérique, assistants conversationnels et fiabilité, sécurité, inclusion numérique) ainsi qu'un état de l'art des solutions existantes. Le chapitre II décrit le contexte de l'étude, général puis propre au projet Naatal Agro. Le chapitre III expose le cadre méthodologique et la conception : besoins, modélisation, choix technologiques et protocole d'évaluation. Le chapitre IV présente les données, la réalisation des fonctionnalités illustrée par des captures de l'application, les résultats, leur discussion et des recommandations. Une conclusion générale ouvre sur les perspectives.

---

# CHAPITRE I : CADRE THÉORIQUE ET CONCEPTUEL

## Section 1 : Revue conceptuelle

### Sous-section 1 : Agriculture numérique, services d'information et d'aide à la décision

L'« agriculture numérique » (ou e-agriculture) désigne l'usage des technologies de l'information et de la communication pour améliorer la production, la commercialisation et la gestion des exploitations. Dans les pays en développement, elle s'appuie surtout sur le téléphone mobile, qui est présent, personnel et peu coûteux à l'usage.

On distingue classiquement quatre familles de services numériques destinés aux producteurs :

1. **Les services d'information** (météo, prix de marché, calendriers culturaux) : ils réduisent l'asymétrie d'information entre le producteur et les acteurs de la commercialisation.
2. **Les services de conseil** (itinéraires techniques, lutte contre les maladies et ravageurs) : ils démultiplient les agents de vulgarisation, trop peu nombreux pour visiter chaque exploitation.
3. **Les services de gestion** (suivi des parcelles, des dépenses, des ventes, des stocks) : ils transforment des habitudes orales en données exploitables.
4. **Les services de mise en relation** (marchés électroniques, financement) : ils étendent l'accès aux acheteurs et au crédit.

Naatal Agro couvre dans sa première version les trois premières familles ; la mise en relation commerciale (place de marché, paiement) est volontairement reportée à une phase ultérieure.

La notion d'**aide à la décision** est centrale : l'application ne remplace ni le jugement du producteur ni le conseiller agricole. Elle lui fournit, au bon moment, une information contextualisée par sa culture, sa zone et la saison.

### Sous-section 2 : Assistants conversationnels, modèles de langage, fiabilité et autonomie

Un **modèle de langage** (LLM) est un système statistique entraîné à produire du texte plausible. Cette qualité est aussi sa faiblesse : lorsqu'il ne dispose pas de l'information demandée, il peut produire une réponse fluide mais fausse, phénomène appelé **hallucination**. Dans un domaine comme l'agronomie, une dose d'engrais ou un produit phytosanitaire inventés peuvent détruire une récolte ou nuire à la santé.

Pour limiter ce risque, la pratique industrielle recourt à la **génération augmentée par la recherche** (RAG, *retrieval-augmented generation*) : le système récupère d'abord des documents pertinents dans une base maîtrisée, puis demande au modèle de rédiger sa réponse uniquement à partir de ces documents, en citant ses sources. Trois principes en découlent, que nous reprenons dans Naatal Agro :

- **Priorité à la base de connaissances** : une réponse issue de fiches vérifiées prime sur une réponse générale.
- **Traçabilité** : chaque affirmation renvoie à une source identifiable ; une citation qui ne correspond à aucune source est rejetée.
- **Aveu d'ignorance** : si l'information manque, le système le dit au lieu de la deviner.

Un second enjeu apparaît dès que l'assistant ne se contente plus de répondre, mais **agit** : créer une dépense, programmer un rappel, enregistrer une récolte. On parle alors d'assistant « à outils » ou d'agent. Le risque change de nature : une erreur n'est plus seulement un mauvais conseil, c'est une écriture non voulue dans les comptes de l'utilisateur. Le principe retenu est de **séparer la proposition de l'exécution** : le modèle propose un plan d'action, le code le valide (outil autorisé, paramètres cohérents, ressource appartenant à l'utilisateur), l'utilisateur confirme explicitement, et seulement alors l'écriture a lieu. Les calculs chiffrés (bilans, marges, ruptures de stock) sont faits par le code et non par le modèle, dont les erreurs arithmétiques sont connues.

La fiabilité n'est toutefois qu'une moitié du problème. L'autre moitié est l'**ergonomie conversationnelle** : un utilisateur pressé attend une réponse brève et claire, qui tient compte de ce qui a déjà été dit et lui suggère la suite. Un document complet recopié dans une bulle de discussion n'est pas une conversation. Pour un utilisateur peu lettré, l'entrée et la sortie doivent en outre être **vocales** : dicter sa question et écouter la réponse.

### Sous-section 3 : Sécurité et protection des données dans une application mobile

Une application agricole manipule des données qui ont une valeur : localisation des parcelles, quantités récoltées, prix de vente, dépenses. Trois notions guident la conception :

- **Authentification** : prouver l'identité de l'utilisateur. Nous utilisons des jetons JWT, avec rotation du jeton de rafraîchissement et liste noire à la déconnexion.
- **Autorisation et isolation** : garantir qu'un utilisateur ne peut accéder qu'à ses propres ressources. L'absence de ce contrôle est connue sous le nom de référence directe non sécurisée à un objet (IDOR) et figure parmi les failles les plus courantes des API.
- **Protection des données personnelles** : informer l'utilisateur, recueillir son consentement et lui permettre d'exporter ou de supprimer ses données. Au Sénégal, la loi n° 2008-12 du 25 janvier 2008 encadre la protection des données à caractère personnel et a créé la Commission de protection des données personnelles (CDP). Un projet de révision est en discussion depuis plusieurs années ; nous n'avons pas trouvé la confirmation qu'un texte de remplacement ait été adopté. [À VÉRIFIER : état actuel du texte applicable et obligations déclaratives auprès de la CDP.]

### Sous-section 4 : Inclusion numérique et fonctionnement en connexion intermittente

Concevoir pour un utilisateur peu lettré ne consiste pas à simplifier le texte : cela consiste à rendre **le texte inutile** pour comprendre l'écran. Quatre principes ont guidé la conception de Naatal Agro :

- **Images d'abord** : chaque action et chaque produit est représenté par une photographie reconnaissable, le texte venant en appui.
- **Mots simples et courts** : un verbe, un nom ; pas de jargon.
- **Voix** : dictée de la question à l'assistant et lecture à voix haute des réponses, de la météo, du calendrier et des pages de marché.
- **Grandes cibles tactiles** et peu d'étapes par tâche.

La couverture réseau en zone rurale est par ailleurs irrégulière. Une application « hors ligne d'abord » repose sur deux mécanismes : une **file d'attente** qui conserve localement les écritures effectuées sans réseau et les rejoue au retour de la connexion, et un **cache de lecture** qui permet de consulter les dernières données connues. Ils doivent respecter la confidentialité : un cache propre à chaque compte, purgé à la déconnexion.

## Section 2 : Revue de littérature et état de l'art

Cette section situe Naatal Agro par rapport à des solutions existantes. [À COMPLÉTER ET À SOURCER : les descriptions ci-dessous sont à vérifier et à enrichir avec des références académiques et institutionnelles ; ne citer que ce qui a été lu.]

**Plantix** (société PEAT, Allemagne) permet de photographier une plante pour identifier une maladie, un ravageur ou une carence ; la plateforme déclare couvrir plus de soixante cultures et des centaines de symptômes, et a été déployée en priorité en Inde. Sa force est le diagnostic par image appuyé sur une très grande base d'images ; ses limites pour notre contexte tiennent à la couverture des cultures sénégalaises et à la dépendance à un service étranger (CGIAR Platform for Big Data in Agriculture ; GSMA).

**Les services d'information par SMS ou par appel vocal** (alertes météo, prix de marché) sont adaptés aux téléphones simples et aux utilisateurs peu lettrés, mais ne permettent ni dialogue ni suivi personnalisé. [À COMPLÉTER : citer des initiatives ouest-africaines précises, vérifiées.]

**Les assistants généralistes fondés sur des modèles de langage** (par exemple ChatGPT ou Gemini) répondent à presque toutes les questions mais sans garantie de source ni adaptation au contexte local : c'est précisément le risque que Naatal Agro encadre.

**Les calendriers culturaux et bases de données publiques** (par exemple le calendrier cultural de la FAO) fournissent des dates de semis et de récolte par zone, mais sous une forme de tableau de données, peu lisible pour un producteur. Naatal Agro les met en forme (« On sème maintenant : tomate ») et cite la source de chaque date.

**Les services publics de vulgarisation** (ANCAR, SAED, ISRA) produisent l'information de référence ; Naatal Agro n'a pas vocation à les remplacer mais à en rendre le contenu accessible, et à renvoyer vers eux pour les décisions à risque (produits phytosanitaires, doses).

**Positionnement de Naatal Agro.**

Table: Positionnement de Naatal Agro par rapport aux solutions existantes (appréciation de l'auteur, à confirmer par l'étude de chaque solution)

| Critère | Applications de diagnostic étrangères | Assistants généralistes | Services SMS | Naatal Agro |
|---|---|---|---|---|
| Contenu adapté au Sénégal | Partiel | Non garanti | Oui, limité | Oui (fiches et calendrier sourcés) |
| Sources citées | Variable | Non | Rarement | Oui, obligatoires |
| Aveu quand l'information manque | Variable | Rare | — | Oui, systématique |
| Suivi des cultures, finances, stocks | Non | Non | Non | Oui |
| Agir à la demande (avec confirmation) | Non | Non | Non | Oui |
| Utilisable à la voix, lecture à voix haute | Non | Variable | Oui (appel vocal) | Oui |
| Utilisable hors ligne | Partiel | Non | Oui | Écritures en file, lecture partielle |
| Dialogue conversationnel | Limité | Oui | Non | Oui, avec mémoire |

Ce tableau situe l'originalité du projet, qui réside dans l'association d'un **suivi d'exploitation**, d'un **assistant à réponses sourcées capable d'agir sous confirmation**, d'une **interface pensée pour les utilisateurs peu lettrés** et d'une **conception adaptée à la connexion intermittente**.
