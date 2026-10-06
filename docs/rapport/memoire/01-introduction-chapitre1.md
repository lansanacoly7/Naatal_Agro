# Introduction générale

## 1. Contexte et justification du sujet

L'agriculture occupe une place centrale dans l'économie et dans la vie quotidienne du Sénégal. Selon les données de la Banque mondiale rapportées par la presse économique, le secteur agricole représente environ 15 % du produit intérieur brut ; la part de la population active qu'il emploie varie, selon les sources et les méthodes de calcul, de 22 % (Banque mondiale) à 27,4 % (enquête harmonisée sur les conditions de vie des ménages, ANSD, 2021), et des chiffres bien plus élevés circulent encore, que les vérificateurs de faits jugent erronés. [À VÉRIFIER AVANT DÉPÔT : reprendre les chiffres dans les publications officielles de l'ANSD et de la Banque mondiale, et citer l'année exacte.] Quelle que soit la mesure retenue, une grande partie des ménages sénégalais, surtout en milieu rural, tire tout ou partie de ses revenus de la production végétale.

Or le producteur prend ses décisions (quand semer, quelle quantité d'engrais apporter, comment traiter une maladie, quand et où vendre) le plus souvent à partir de son expérience et de ce que lui disent ses voisins. L'information agronomique fiable existe (instituts de recherche comme l'ISRA, services de conseil comme l'ANCAR ou la SAED), mais elle est dispersée, rédigée pour des spécialistes, rarement à jour et difficilement accessible au moment précis où le producteur en a besoin. De même, les prix des marchés et les prévisions météorologiques locales ne lui parviennent pas toujours à temps pour orienter une décision.

Dans le même temps, le téléphone mobile est devenu un outil quotidien : l'autorité de régulation des télécommunications et des postes (ARTP) et les rapports de DataReportal font état de plus de 24 millions de connexions mobiles pour environ 18 millions d'habitants, dont la quasi-totalité en haut débit mobile (3G, 4G ou 5G) [chiffres à reprendre depuis le rapport ARTP du quatrième trimestre 2024 et vérifier]. Un smartphone peut donc devenir le point d'accès à une information agricole utile, à condition que l'application soit simple, fonctionne avec une connexion irrégulière et ne mente pas à son utilisateur.

C'est dans ce contexte que s'inscrit **Naatal Agro**, une application mobile d'aide à la décision pour les producteurs sénégalais, développée dans le cadre de notre projet de fin de formation à l'Institut Supérieur d'Enseignement Professionnel (ISEP).

## 2. Problématique

Les solutions numériques agricoles existantes se heurtent à trois difficultés dans le contexte sénégalais. Les applications internationales de diagnostic ou de conseil, comme Plantix, sont conçues pour d'autres cultures et d'autres marchés. Les assistants fondés sur des modèles de langage répondent avec aisance mais peuvent « halluciner », c'est-à-dire produire une dose, une date ou un produit plausibles mais faux, ce qui est grave en agronomie. Enfin, beaucoup de solutions supposent une connexion permanente et un utilisateur habitué aux interfaces complexes.

La problématique de ce travail est donc la suivante :

> **Comment concevoir et réaliser une application mobile qui aide concrètement un producteur sénégalais à décider (cultiver, traiter, vendre) en s'appuyant sur des informations agronomiques vérifiables et sourcées, tout en restant simple, sûre et utilisable avec une connexion irrégulière ?**

## 3. Questions de recherche

**Question principale.** Comment un assistant conversationnel peut-il fournir à un producteur sénégalais des conseils agronomiques à la fois accessibles (courts, en français simple) et fiables (sourcés, sans invention) ?

**Questions spécifiques.**

1. Quelles fonctionnalités (suivi des cultures, finances, stocks, marchés, météo, assistant) répondent aux besoins prioritaires d'un producteur et dans quel ordre les réaliser ?
2. Comment organiser les connaissances agronomiques pour que l'assistant s'appuie d'abord sur des fiches vérifiées et signale ce qu'il ne sait pas ?
3. Comment protéger les données personnelles et professionnelles de chaque utilisateur dans une application dont les ressources sont toutes privées ?
4. Comment garantir qu'une action effectuée sans réseau n'est pas perdue et que l'application reste utilisable en connexion dégradée ?
5. Comment mesurer objectivement la qualité du produit (sécurité, performance, fiabilité) sans se fonder sur des impressions ?

## 4. Objectif général et objectifs subsidiaires

**Objectif général.** Concevoir, réaliser et évaluer Naatal Agro, une application mobile (Flutter) adossée à une interface de programmation (Django REST Framework), qui accompagne le producteur sénégalais dans le suivi de ses cultures et lui fournit des conseils agronomiques sourcés grâce à un assistant conversationnel.

**Objectifs subsidiaires.**

- O1. Spécifier les besoins du producteur et en déduire un périmètre réaliste pour une première version.
- O2. Modéliser le système (cas d'utilisation, classes, séquences, base de données).
- O3. Constituer une base de fiches agronomiques sourcées et l'exploiter en priorité dans les réponses de l'assistant.
- O4. Sécuriser l'application : authentification, isolation des données par utilisateur, limitation des abus, droits sur les données personnelles.
- O5. Assurer la résilience hors ligne : file d'attente des actions et cache de lecture.
- O6. Mettre en place une démarche qualité mesurable : tests automatisés, intégration continue, mesure de performance.
- O7. Documenter honnêtement ce qui est réalisé, ce qui est simulé et ce qui est prévu.

## 5. Hypothèses de recherche

- **H1.** Un assistant qui répond d'abord à partir de fiches sourcées, et déclare explicitement lorsqu'une information est absente, réduit le risque de conseil erroné par rapport à un assistant qui répond librement.
- **H2.** Des réponses courtes, structurées et suivies de questions suggérées sont mieux adaptées à un producteur qui dispose de peu de temps qu'un texte exhaustif.
- **H3.** Une isolation systématique des données au niveau du serveur, vérifiée par des tests d'accès croisé, suffit à empêcher qu'un utilisateur lise les données d'un autre.
- **H4.** Une file d'attente locale des écritures et un cache de lecture rendent l'application utilisable en connexion intermittente sans perte de données.

Ces hypothèses sont éprouvées par des tests automatisés et des mesures décrits au chapitre IV ; l'hypothèse H2 relève en outre de l'expérience utilisateur et appelle une validation terrain que nous présentons comme perspective (voir chapitre IV, section 2).

## 6. Méthodologie retenue

Le projet a suivi une démarche itérative, par blocs fonctionnels, avec les principes suivants :

- **Recueil et formalisation des besoins** à partir de l'analyse du contexte, d'un benchmark de solutions existantes et de la définition d'un public cible (le producteur sénégalais, utilisateur principal de la première version).
- **Modélisation en UML** (cas d'utilisation, classes, séquences) et conception relationnelle de la base de données.
- **Développement par domaines** : un backend modulaire (utilisateurs, agriculture, finances, stocks, marchés, météo, notifications, assistant, données personnelles) et une application mobile organisée par fonctionnalités.
- **Qualité par la preuve** : chaque fonctionnalité déclarée « faite » s'appuie sur un test automatisé ou une commande reproductible ; les audits de sécurité et de performance ont donné lieu à des corrections vérifiées.
- **Gestion de version et revue** : un dépôt Git, des branches de travail, un commit par sujet, des revues de code. [À COMPLÉTER : préciser le rôle de chaque contributeur du projet et, si vous le souhaitez, l'usage d'outils d'assistance à la programmation fondés sur l'intelligence artificielle, accompagnés de revues et de tests.]
- **Transparence** : un document d'état distingue ce qui est réalisé, partiel, simulé volontairement ou seulement prévu.

## 7. Annonce du plan

Ce mémoire comporte quatre chapitres. Le chapitre I présente le cadre théorique et conceptuel (agriculture numérique, assistants conversationnels et fiabilité) ainsi qu'un état de l'art des solutions existantes. Le chapitre II décrit le contexte de l'étude, général puis propre au projet Naatal Agro. Le chapitre III expose le cadre méthodologique et la conception : besoins, modélisation, choix technologiques et protocole d'évaluation. Le chapitre IV présente les données, la réalisation des fonctionnalités, les résultats, leur discussion et des recommandations. Une conclusion générale ouvre sur les perspectives.

---

# CHAPITRE I : CADRE THÉORIQUE ET CONCEPTUEL

## Section 1 : Revue conceptuelle

### Sous-section 1 : Agriculture numérique, services d'information et d'aide à la décision

L'« agriculture numérique » (ou e-agriculture) désigne l'usage des technologies de l'information et de la communication pour améliorer la production, la commercialisation et la gestion des exploitations. Dans les pays en développement, elle s'appuie surtout sur le téléphone mobile, car celui-ci a franchi des obstacles que d'autres infrastructures n'ont pas franchis : il est présent, personnel et peu coûteux à l'usage.

On distingue classiquement quatre familles de services numériques destinés aux producteurs :

1. **Les services d'information** (météo, prix de marché, calendriers cultureaux) : ils réduisent l'asymétrie d'information entre le producteur et les acteurs de la commercialisation.
2. **Les services de conseil** (itinéraires techniques, lutte contre les maladies et ravageurs) : ils démultiplient les agents de vulgarisation, trop peu nombreux pour visiter chaque exploitation.
3. **Les services de gestion** (suivi des parcelles, des dépenses, des ventes, des stocks) : ils transforment des habitudes orales en données exploitables.
4. **Les services de mise en relation** (marchés électroniques, financement) : ils étendent l'accès aux acheteurs et au crédit.

Naatal Agro se concentre dans sa première version sur les trois premières familles ; la mise en relation commerciale (place de marché, paiement) est volontairement reportée à une phase ultérieure.

La notion d'**aide à la décision** est centrale : l'application ne remplace pas le jugement du producteur ni le conseiller agricole, elle lui fournit au bon moment une information contextualisée (sa culture, sa zone, la saison).

### Sous-section 2 : Assistants conversationnels, modèles de langage et fiabilité

Un **modèle de langage** (LLM) est un système statistique entraîné à produire du texte plausible. Cette qualité est aussi sa faiblesse : lorsqu'il ne dispose pas de l'information demandée, il peut produire une réponse fluide mais fausse, phénomène appelé **hallucination**. Dans un domaine comme l'agronomie, une dose d'engrais ou un produit phytosanitaire inventés peuvent détruire une récolte ou nuire à la santé.

Pour limiter ce risque, la littérature et la pratique industrielle recourent à la **génération augmentée par la recherche** (RAG, *retrieval-augmented generation*) : le système récupère d'abord des documents pertinents dans une base maîtrisée, puis demande au modèle de rédiger sa réponse uniquement à partir de ces documents, en citant ses sources. Trois principes en découlent, que nous reprenons dans Naatal Agro :

- **Priorité à la base de connaissances** : une réponse issue de fiches vérifiées prime sur une réponse générale.
- **Traçabilité** : chaque affirmation renvoie à une source identifiable ; une citation qui ne correspond à aucune source est rejetée.
- **Aveu d'ignorance** : si l'information manque, le système le dit au lieu de la deviner.

La fiabilité n'est toutefois qu'une moitié du problème. L'autre moitié est l'**ergonomie conversationnelle** : un utilisateur pressé attend une réponse brève, claire, qui tient compte de ce qui a déjà été dit (mémoire de la conversation) et qui lui suggère la suite. Un document complet recopié dans une bulle de discussion n'est pas une conversation. Nos choix de conception (réponses d'environ soixante mots, puces, questions suggérées, historique transmis au modèle) répondent à cette exigence et sont décrits au chapitre IV.

### Sous-section 3 : Sécurité et protection des données dans une application mobile

Une application agricole manipule des données qui ont une valeur : localisation des parcelles, quantités récoltées, prix de vente, dépenses. Trois notions guident la conception :

- **Authentification** : prouver l'identité de l'utilisateur. Nous utilisons des jetons JWT à durée courte, avec rotation du jeton de rafraîchissement et liste noire à la déconnexion.
- **Autorisation et isolation** : garantir qu'un utilisateur ne peut accéder qu'à ses propres ressources. L'absence de ce contrôle est connue sous le nom de référence directe non sécurisée à un objet (IDOR) et figure parmi les failles les plus courantes des API.
- **Protection des données personnelles** : informer l'utilisateur, recueillir son consentement et lui permettre d'exporter ou de supprimer ses données. Au Sénégal, la loi n° 2008-12 sur la protection des données à caractère personnel encadre ces droits. [À VÉRIFIER : référence juridique exacte et obligations déclaratives auprès de la Commission de protection des données personnelles.]

### Sous-section 4 : Fonctionnement en connexion intermittente

La couverture réseau en zone rurale est irrégulière. Une application « hors ligne d'abord » repose sur deux mécanismes : une **file d'attente** qui conserve localement les écritures effectuées sans réseau et les rejoue au retour de la connexion, et un **cache de lecture** qui permet de consulter les dernières données connues. Ils doivent respecter la confidentialité : un cache propre à chaque compte, purgé à la déconnexion.

## Section 2 : Revue de littérature et état de l'art

Cette section situe Naatal Agro par rapport à des solutions existantes. [À COMPLÉTER ET À SOURCER : les descriptions ci-dessous sont à vérifier et à enrichir avec des références académiques et institutionnelles ; ne citer que ce que vous avez lu.]

**Plantix** (société PEAT, Allemagne) permet de photographier une plante pour identifier une maladie, un ravageur ou une carence ; la plateforme déclare couvrir plus de soixante cultures et des centaines de symptômes, et a été déployée en priorité en Inde. Sa force est le diagnostic par image appuyé sur une très grande base d'images ; ses limites pour notre contexte tiennent à la couverture des cultures sénégalaises et à la dépendance à un service étranger. (Sources : CGIAR Platform for Big Data in Agriculture ; GSMA.)

**Les services d'information par SMS ou par appel vocal** (alertes météo, prix de marché) sont adaptés aux téléphones simples et aux utilisateurs peu lettrés, mais ne permettent pas un dialogue ni un suivi personnalisé. [À COMPLÉTER : citer des initiatives ouest-africaines précises que vous aurez vérifiées.]

**Les assistants généralistes fondés sur des modèles de langage** (ChatGPT, Gemini) répondent à presque toutes les questions mais sans garantie de source ni adaptation au contexte local : c'est précisément le risque que Naatal Agro encadre.

**Les services publics de vulgarisation** (ANCAR, SAED, ISRA) produisent l'information de référence ; Naatal Agro n'a pas vocation à les remplacer mais à en rendre le contenu accessible, et à renvoyer vers eux pour les décisions à risque (produits phytosanitaires, doses).

**Positionnement de Naatal Agro.**

| Critère | Applications de diagnostic étrangères | Assistants généralistes | Services SMS | Naatal Agro |
|---|---|---|---|---|
| Contenu adapté au Sénégal | Partiel | Non garanti | Oui, limité | Oui (fiches sourcées) |
| Sources citées | Variable | Non | Rarement | Oui, obligatoires |
| Aveu quand l'information manque | Variable | Rare | — | Oui, systématique |
| Suivi des cultures, finances, stocks | Non | Non | Non | Oui |
| Utilisable hors ligne | Partiel | Non | Oui | Écriture et lecture (cultures) |
| Dialogue conversationnel | Limité | Oui | Non | Oui, avec mémoire |

Ce tableau reflète des positionnements généraux à confirmer par l'étude de chaque solution ; il sert à situer l'originalité du projet, qui réside dans l'association d'un **suivi d'exploitation**, d'un **assistant à réponses sourcées** et d'une **conception pensée pour la connexion intermittente**.
