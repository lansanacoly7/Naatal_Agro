# CHAPITRE IV : CADRE ANALYTIQUE ET RÉALISATION

## Section 1 : Présentation et traitement des données

### Sous-section 1 : Description des données (sources, structure, qualité)

Naatal Agro manipule trois catégories de données de nature très différente, dont la qualité n'appelle pas les mêmes précautions.

**a) Les données de connaissance : les fiches agronomiques.** La base contient **19 fiches** : 12 légumes, 4 céréales, 2 légumineuses et 1 fruit (oignon, tomate industrielle, arachide, mil, riz irrigué, carotte, sorgho, mangue, pomme de terre, chou, aubergine, piment, gombo, patate douce, manioc, melon, bissap, maïs, niébé). Chaque fiche est structurée en rubriques (résumé, zones de culture, calendrier, sol et semis, besoins en eau, fertilisation, maladies et ravageurs, récolte, rendement, limites) et porte une liste de **sources**, soit 27 références au total dont 26 relèvent de publications sénégalaises (ISRA, CIRAD, SAED, ministère de l'Agriculture, Université Gaston Berger, CERAAS-UCAD…) et une d'Afrique de l'Ouest (IFDC), marquée comme « référence hors Sénégal, à adapter ».

La qualité de ces données est encadrée par trois règles : (1) **traçabilité** : un test automatique vérifie que chaque rubrique renseignée renvoie à une source existante ; (2) **honnêteté sur l'âge et la portée** : plusieurs fiches s'appuient sur un bilan de la recherche agricole de 2005, ce qui est signalé comme limite et impose de confirmer les variétés et les doses auprès d'un conseiller (ANCAR, SAED) ; (3) **absence de remplissage artificiel** : lorsqu'une rubrique n'est pas documentée (par exemple, les maladies du riz), elle est laissée vide et l'assistant déclare l'information indisponible au lieu de la deviner.

Les fiches sont stockées dans un fichier de référence versionné, synchronisé en base à chaque migration, sans écraser les modifications faites par l'administrateur. Une **file de validation** (propositions de connaissance) permet d'enrichir les fiches : une proposition porte le texte, une citation et la source ; seule une validation humaine l'intègre à la fiche.

**b) Les données d'exploitation de l'utilisateur** : cultures, activités, transactions, ventes, stocks, signalements, échanges avec l'assistant. Elles sont saisies par l'utilisateur, **strictement privées**, et filtrées par propriétaire à chaque requête. Leur qualité dépend de la saisie ; l'application valide les formats (dates, montants positifs, unités) côté serveur.

**c) Les données publiques de contexte** : marchés, prix, produits et météo. La météo est obtenue auprès d'un service externe lorsqu'une clé d'accès est configurée. **Les marchés, prix et produits présents dans l'environnement de démonstration sont des données d'amorçage (« seed ») et non un flux de prix en temps réel.** C'est une limite que nous assumons : l'alimentation par une source de prix officielle ou collaborative fait partie des perspectives.

### Sous-section 2 : Chargement, validation et protection des données

[Pistes à développer selon la place disponible : (1) le chargement des fiches depuis le fichier JSON et la commande d'export ; (2) la pagination optionnelle (`page`, `page_size`) ; (3) le nettoyage du cache local à la déconnexion ; (4) la durée de conservation des échanges avec l'assistant ; (5) la version de la politique de confidentialité et la date du consentement.]

## Section 2 : Réalisation et analyse des fonctionnalités

### Sous-section 1 : Implémentation des interfaces utilisateur

L'application suit une navigation à cinq onglets : **Accueil, Mes cultures, Marchés, Naatal IA, Profil**. La charte graphique repose sur un vert profond (couleur de l'agriculture et de l'action), des cartes blanches sur fond gris très clair, des coins arrondis et des ombres douces. Les principes appliqués : peu de clics, textes courts, grandes zones tactiles, retours visuels immédiats (chargement, vide, erreur).

[Insérer ici des captures d'écran d'après le dossier `docs/Captures/` et de nouvelles captures de l'application à jour : connexion ; tableau de bord (météo, tâches du jour, prix, produits) ; Mes cultures et catalogue ; ajout d'une culture (bandeau, cartes, suggestions de cultures, dates côte à côte) ; performances financières et saisie d'une transaction ; carte des marchés ; assistant Naatal IA. Légender chaque figure.]

**L'assistant Naatal IA** mérite un développement particulier, car il concentre les choix de conception les plus importants.

*Chaîne de traitement d'une question.*

1. L'application envoie la question et les derniers échanges de la conversation (huit messages au plus).
2. Le serveur **détecte la culture et le sujet** (semis, fertilisation, maladies, eau, récolte, rendement, cycle) en s'appuyant sur les noms de la fiche et leurs alias. Si la question seule ne désigne aucune culture (« et pour l'engrais ? »), il utilise les messages précédents pour la retrouver.
3. Il **extrait de la base les rubriques correspondantes**, avec leurs sources numérotées.
4. Il demande au modèle de langage de rédiger une **réponse courte** en n'utilisant que ces fiches, en citant au moins une source, et en terminant par deux ou trois **questions suggérées**.
5. Il **valide** la réponse : toute citation dont le numéro ne correspond à aucune source est supprimée ; une réponse sans aucune citation valide est rejetée et remplacée par un résumé construit directement depuis les fiches.
6. Il **signale ce qui manque** (« information non disponible dans nos fiches vérifiées ») et, si une source vient d'ailleurs qu'un référentiel sénégalais, ajoute un avertissement.
7. À défaut de fiche sur le sujet, la réponse est un **conseil général clairement étiqueté** comme non issu des fiches vérifiées, à confirmer auprès d'un conseiller.

*Évolution issue d'un retour d'usage.* Une première version renvoyait, pour la question « je veux cultiver les patates douces », la fiche complète d'un seul bloc, sans mise en forme. Ce défaut a été identifié lors d'une revue de l'écran : l'assistant était exact mais inutilisable pour un producteur pressé. Il a conduit à la refonte décrite ci-dessus : réponses d'environ soixante mots, une question de précision, des puces, un format aéré, des boutons de questions suggérées sous la dernière réponse, et le masquage des repères de citation dans le texte (les sources restent accessibles par un bouton dédié). Ce cas illustre l'équilibre recherché entre **fiabilité** (hypothèse H1) et **ergonomie conversationnelle** (hypothèse H2).

*Disponibilité.* Un incident a montré la nécessité d'un mode dégradé : le modèle utilisé par défaut a été retiré par le fournisseur pour les nouveaux comptes, ce qui a fait basculer l'assistant sur le texte brut des fiches. Le mode de repli a bien fonctionné (l'utilisateur obtient toujours une réponse sourcée), mais l'incident a conduit à changer de modèle, à ajouter un nouvel essai en cas de pic de demande, et à rendre le nom du modèle configurable.

### Sous-section 2 : Synthèse et discussion des résultats

**Sécurité.** Un audit du serveur a mis en évidence plusieurs défauts graves qui ont été corrigés et verrouillés par des tests :

- des ressources privées accessibles par simple identifiant (référence directe non sécurisée) : l'accès est désormais filtré par propriétaire et des tests d'accès croisé en vérifient chaque ressource ;
- un chemin d'exécution de requêtes SQL construites à partir de texte libre dans l'assistant : il a été supprimé ;
- l'absence de limites contre les abus : des limites de débit protègent la connexion (10 tentatives par minute) et l'assistant (30 questions par heure) ;
- l'absence de politique de mot de passe, de validation du numéro et d'invalidation des jetons : ils ont été ajoutés (rotation des jetons de rafraîchissement, liste noire à la déconnexion, validation du format de numéro) ;
- l'absence de droits sur les données : une politique de confidentialité versionnée, un export complet des données et une suppression de compte avec redemande du mot de passe sont disponibles.

**Performance.** La mesure a révélé des requêtes « N+1 » : pour 300 cultures, la liste des cultures exécutait 301 requêtes SQL, la liste des ventes 301 et l'export des données 310. Après correction (chargement groupé des activités et du nom de la culture), ces points d'accès exécutent respectivement 2, 1 et 10 requêtes, indépendamment du volume. Les temps de réponse mesurés sur la machine de développement évoluent ainsi : liste des ventes d'environ 927 ms à environ 290 ms ; export d'environ 4,6 s à environ 2,8 s ; liste complète des cultures de 1,5 s à environ 1,0–1,2 s, et environ 100 ms avec une pagination de 20 éléments. Ces temps absolus ne se transposent pas à un serveur de production (mesures faites avec SQLite et le client de test) ; **le nombre de requêtes est l'indicateur fiable**, et un test automatique échoue désormais si un point d'accès redevient N+1.

**Résilience.** Les écritures effectuées sans réseau sont placées dans une file locale et rejouées au retour de la connexion ; les cultures sont mises en cache localement pour la lecture, par compte, avec une expiration de sept jours et une purge à la déconnexion.

**Qualité du code.** À la date de rédaction : 203 tests du serveur et 41 tests de l'application passent ; l'analyse statique de l'application ne signale aucun problème ; le pipeline d'intégration continue exécute les tests, la vérification des migrations, le contrôle de configuration de production et l'analyse du code. Un défaut réel a été trouvé et corrigé grâce à la revue des écrans : l'API renvoyait les montants décimaux sous forme de texte (« 5689.00 ») et l'application les attendait sous forme de nombre, ce qui faisait échouer l'historique des transactions ; un test de régression couvre désormais ce cas.

**Discussion par rapport aux hypothèses.**

| Hypothèse | Verdict | Éléments |
|---|---|---|
| H1 : réponses sourcées et aveu d'ignorance réduisent le risque d'erreur | **Confirmée sur le plan technique** | Tests de citation, de rejet des citations inventées et de signalement des manques ; le mode de repli répond depuis les fiches. Elle ne garantit pas l'exactitude des fiches elles-mêmes (limites de 2005) |
| H2 : réponses courtes et questions suggérées adaptées au producteur | **Non démontrée** | Conception et corrections issues d'une revue ; aucune mesure auprès d'utilisateurs : validation terrain prévue |
| H3 : isolation serveur suffisante | **Confirmée sur le périmètre testé** | Tests d'accès croisé sur chaque ressource privée ; non équivalent à un audit externe |
| H4 : file et cache rendent l'application utilisable hors connexion | **Partiellement confirmée** | File d'attente testée ; cache de lecture limité aux cultures |

**Limites et éléments simulés (en toute transparence).**

- La **vérification du numéro par SMS et la réinitialisation du mot de passe** sont présentées par des écrans volontairement simulés : aucun SMS n'est envoyé. L'implémentation est prévue.
- Les **notifications poussées** sont prises en charge par le serveur mais l'application ne s'enregistre pas encore.
- La **recherche web** de l'assistant (pour les informations absentes de la base, avec validation) est conçue mais non implémentée.
- La **lecture hors ligne** ne couvre que les cultures.
- La version Android de publication est signée avec une clé de débogage : **elle n'est pas distribuable en l'état**.
- Les **prix de marché** de démonstration sont des données d'amorçage.
- La **base de production (PostgreSQL)**, le déploiement automatique et le suivi des plantages ne sont pas en place.
- Aucune **évaluation auprès d'utilisateurs** n'a encore été conduite.
- L'application n'a pas été évaluée sur un appareil physique pour l'ensemble des parcours. [À COMPLÉTER ou à retirer selon la réalité.]

### Sous-section 3 : Recommandations

*Pour la suite du projet.*

1. **Valider sur le terrain** avec des producteurs et des conseillers, selon le protocole décrit au chapitre III, et ajuster les réponses de l'assistant.
2. **Actualiser et élargir les fiches** avec l'appui de l'ANCAR, de l'ISRA et de la SAED ; documenter les rubriques manquantes (maladies du riz) ; remplacer les sources anciennes par des références récentes.
3. **Implémenter la vérification par SMS** (génération et expiration du code, limite de tentatives et d'envois, jamais de code dans une réponse de l'API).
4. **Brancher une source de prix réelle** (observatoires de marché ou collecte participative) et indiquer la date de chaque prix.
5. **Ajouter la lecture à voix haute des réponses** de l'assistant, pour les utilisateurs peu à l'aise avec la lecture, et envisager les langues nationales.
6. **Étendre le cache hors ligne** à l'ensemble des listes et ajouter un test de bout en bout de l'application vers le serveur.
7. **Préparer la mise en production** : PostgreSQL, restauration de sauvegarde réellement testée, signature de publication Android, suivi des plantages, déploiement automatique.
8. **Compléter le cadre juridique** : identité du responsable de traitement, validation du texte de la politique de confidentialité, déclaration auprès de l'autorité de protection des données.

*Pour la gouvernance des contenus.* Maintenir la règle « base d'abord » : toute extension de l'assistant vers le web ne doit passer que par des domaines de confiance et une validation humaine avant intégration aux fiches.

---

# Conclusion générale

Ce travail visait à concevoir une application mobile utile et honnête pour le producteur sénégalais. Naatal Agro réunit dans une application unique le suivi de l'exploitation (cultures, finances, stocks), l'information de contexte (marchés, météo) et un assistant conversationnel qui répond d'abord à partir de **fiches agronomiques sourcées**, déclare ce qu'il ne sait pas, tient compte de la conversation et propose la suite. Les choix de sécurité (isolation des données, authentification à jetons tournants, limitation des abus, droits sur les données personnelles), de résilience (file hors ligne, cache de lecture) et de performance (suppression des requêtes redondantes, mesure automatisée) ont été vérifiés par des tests et non par de simples affirmations.

Les résultats confirment techniquement la fiabilité de la chaîne de réponse (hypothèse H1), l'isolation des données (H3) et en partie la résilience hors ligne (H4). L'adéquation des réponses courtes au besoin réel des producteurs (H2) reste à démontrer sur le terrain. Le projet présente aussi des limites que ce mémoire a énoncées sans détour : certaines fiches s'appuient sur des sources anciennes, la vérification par SMS est simulée, les prix de démonstration ne sont pas un flux réel et aucune évaluation auprès d'utilisateurs n'a eu lieu.

Les perspectives sont claires : validation terrain, enrichissement des contenus avec les institutions agricoles, vérification par SMS, prix réels, lecture à voix haute, mise en production, puis, dans des phases ultérieures, une interface web d'administration et des services de mise en relation commerciale. Au-delà du produit, ce projet nous a appris qu'en agriculture comme ailleurs, **la confiance se construit sur la transparence** : une application qui dit « je ne sais pas, voici qui consulter » est plus utile qu'une application qui répond toujours.

---

# Webographie

[À COMPLÉTER : ne lister que les documents réellement consultés, avec l'auteur, le titre, l'année, l'URL et la date de consultation. Voici les sources repérées pendant la préparation de ce brouillon, à ouvrir et vérifier avant de les citer.]

- Africa Check, « Non, le secteur agricole n'emploie pas 70 % de la population sénégalaise », https://africacheck.org/fr/fact-checks/articles/non-le-secteur-agricole-nemploie-pas-70-de-la-population-senegalaise
- Agence Ecofin, « Sénégal : l'activité économique s'est accélérée en 2023 grâce au dynamisme du secteur agricole (Banque mondiale) », https://www.agenceecofin.com/agro/1406-119542-senegal-l-activite-economique-s-est-acceleree-en-2023-grace-au-dynamisme-du-secteur-agricole-banque-mondiale
- ARTP, « Rapport marché des télécoms, quatrième trimestre 2024 », https://artp.sn/sites/default/files/2025-03/RAPPORT%20MARCHE%20TELECOMS%20T4%202024_0.pdf
- DataReportal, « Digital in Senegal », https://datareportal.com/digital-in-senegal
- CGIAR Platform for Big Data in Agriculture, « Plant disease diagnosis using artificial intelligence: a case study on Plantix », https://bigdata.cgiar.org/digital-intervention/plant-disease-diagnosis-using-artificial-intelligence-a-case-study-on-plantix/
- GSMA, « Detecting and managing crop pests and diseases with AI: Insights from Plantix », https://www.gsma.com/solutions-and-impact/connectivity-for-good/mobile-for-development/programme/agritech/detecting-and-managing-crop-pests-and-diseases-with-ai-insights-from-plantix/
- Sources des fiches agronomiques : ISRA, CIRAD, SAED, ministère de l'Agriculture et de l'Équipement rural (projet PIESAN), IFDC, AfricaRice, Université Gaston Berger, CERAAS-UCAD, DAPSA (voir le fichier `backend/apps/agriculture/data/agronomic_guides.json` pour les titres, années et liens).
- Documentation technique : Flutter, Django, Django REST Framework, SimpleJWT, Riverpod. [Ajouter les URL et dates de consultation.]
