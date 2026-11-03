# CHAPITRE IV : CADRE ANALYTIQUE ET RÉALISATION

## Section 1 : Présentation et traitement des données

### Sous-section 1 : Description des données (sources, structure, qualité)

Naatal Agro manipule quatre catégories de données de nature très différente, dont la qualité n'appelle pas les mêmes précautions.

**a) Les données de connaissance : fiches agronomiques et calendrier agricole.** La base contient **19 fiches** : 12 légumes, 4 céréales, 2 légumineuses et 1 fruit. Chaque fiche est structurée en rubriques (résumé, zones de culture, calendrier, sol et semis, besoins en eau, fertilisation, maladies et ravageurs, récolte, rendement, limites) et porte une liste de **sources** ; au total, 14 références distinctes y sont citées, issues pour l'essentiel de publications sénégalaises (ISRA, CIRAD, SAED, ministère de l'Agriculture, Université Gaston Berger, CERAAS-UCAD). Le **calendrier agricole** compte **128 fenêtres de semis et de récolte** couvrant **31 cultures** réparties sur six zones agro-écologiques (Niayes, vallée du fleuve, Bassin arachidier, centre-est, sylvopastorale, Casamance) et une catégorie « toute zone ». Chaque fenêtre renvoie à l'une de quatre sources citées : le calendrier cultural de la FAO pour le Sénégal (2021), le bilan de la recherche agricole de l'ISRA (2005), l'étude de la culture des agrumes publiée par l'ISRA, la FAO et le CDH (2012), et le pré-diagnostic de la filière mangue du CIRAD (2017).

La qualité de ces données est encadrée par quatre règles :

1. **Traçabilité** : un test automatique vérifie que chaque rubrique renseignée renvoie à une source existante ; le calendrier applique la règle « chaque date vient d'une source citée ».
2. **Honnêteté sur l'âge et la portée** : plusieurs sources datent de 2005 à 2017, ce qui est signalé comme limite et impose de confirmer variétés et doses auprès d'un conseiller (ANCAR, SAED).
3. **Absence de remplissage artificiel** : lorsqu'une rubrique n'est pas documentée, elle est laissée vide et l'assistant déclare l'information indisponible au lieu de la deviner ; une culture sans source n'apparaît pas avec des dates inventées mais est signalée « non documentée ». Une recherche documentaire menée en fin de projet a établi que **23 noms de cultures** du calendrier ne disposent pas encore d'une fiche technique sourcée récente et vérifiable.
4. **Validation humaine** : une file de validation (propositions de connaissance) permet d'enrichir les fiches ; une proposition porte le texte, une citation et la source, et seule une validation humaine l'intègre.

**b) Les données d'exploitation de l'utilisateur** : cultures, activités, récoltes, ventes, dépenses, stocks, signalements, échanges avec l'assistant. Elles sont saisies par l'utilisateur, **strictement privées** et filtrées par propriétaire à chaque requête. Un compte neuf est vide : l'application ne lui affiche aucune donnée d'exemple. Leur qualité dépend de la saisie ; le serveur valide les formats (dates, montants positifs, quantités) et refuse, par exemple, une vente supérieure au stock disponible.

**c) Les données de marché.** La base de développement contient **20 marchés** répartis dans **10 régions**, **35 produits** et environ **20 900 relevés de prix** couvrant la période du 6 septembre au 24 octobre 2026. **Ces prix ne sont pas issus d'une source officielle : ils ont été générés par un script d'amorçage** (`generate_market_data`) pour éprouver l'interface et les performances. L'application le signale à l'utilisateur (« relevés indicatifs, non officiels ») et affiche la date du dernier relevé. Le branchement d'une source de prix réelle fait partie des recommandations. [À COMPLÉTER : décrire la source de prix réelle visée (observatoire de marché, collecte participative) et l'état des démarches.]

**d) Les données de contexte externes.** La météo est obtenue en temps réel auprès d'Open-Meteo pour les coordonnées de l'utilisateur ou la région qu'il choisit ; si elle est indisponible, l'application l'indique et **ne montre jamais la météo d'une autre région**. Les itinéraires sont calculés par OSRM et les fonds de carte proviennent de CARTO (données OpenStreetMap).

### Sous-section 2 : Chargement, validation et protection des données

Les fiches et le calendrier sont stockés dans des fichiers de référence versionnés, synchronisés en base par des migrations, sans écraser les modifications faites par l'administrateur. Les listes sont paginées à la demande (paramètres `page` et `page_size`). À la déconnexion, tout le cache local de l'utilisateur est purgé et l'état en mémoire de l'application est détruit. Le consentement à la politique de confidentialité est enregistré avec sa version et sa date ; l'utilisateur peut exporter l'ensemble de ses données et supprimer son compte. Les échanges avec l'assistant sont journalisés **sans leur contenu** pour le suivi d'usage des fournisseurs de modèles. [À COMPLÉTER : durée de conservation des échanges avec l'assistant et responsable du traitement.]

## Section 2 : Réalisation et analyse des fonctionnalités

### Sous-section 1 : Implémentation des interfaces utilisateur

L'application suit une navigation à cinq onglets : **Accueil, Cultures, Dashboard (Mon exploitation), Marchés et Naatal IA**. Le profil est accessible par l'avatar placé en haut à gauche. La charte graphique repose sur un fond sahélien chaud, un vert profond (couleur de l'agriculture et de l'action), des photographies de produits et de gestes agricoles, des coins arrondis et des ombres douces. Les principes appliqués, détaillés en section 1 du chapitre I, sont : images d'abord, mots simples, voix, grandes zones tactiles, retours visuels immédiats (chargement, vide, erreur). Les captures ci-dessous ont été prises sur l'application réelle, exécutée en application web progressive, avec un **compte de démonstration** (« Awa Diop ») et une copie isolée de la base de développement ; la météo affichée est la météo réelle du moment de la capture, et les prix de marché sont les données d'amorçage décrites plus haut.

**Entrée dans l'application.** Trois écrans accueillent le nouvel utilisateur : une présentation, une inscription réduite à deux champs (nom et numéro de téléphone), puis la connexion. L'inscription a été volontairement simplifiée : la localisation est détectée automatiquement et une culture est suggérée en fonction de la zone et de la saison.

!![Entrée dans l'application : présentation, inscription et connexion](figures/01-onboarding.jpg|figures/02-inscription.jpg|figures/03-connexion.jpg){w=4.9}

**Accueil et météo.** L'accueil salue l'utilisateur, affiche la météo de sa zone, le bandeau du calendrier (« On sème : tomate ») et six actions rapides représentées par des photographies : vendre, récolter, stock, dépenses, marchés, aide de l'assistant. La page météo traduit les données en mots simples (« Il fait bon », « Pas de pluie aujourd'hui »), propose un conseil (« Que faire ? ») et peut être écoutée.

!![Accueil, actions rapides et page météo](figures/04-accueil.jpg|figures/05-actions-rapides.jpg|figures/06-meteo.jpg){w=4.9}

**Calendrier agricole et fiches techniques.** Le calendrier indique, mois par mois et pour la zone choisie, ce qu'il faut semer maintenant et ce qu'on récolte, avec un bouton « Écouter ». Le catalogue des fiches techniques présente les 19 cultures documentées avec leur photographie, filtrables par famille.

!![Calendrier agricole et fiches techniques](figures/07-calendrier.jpg|figures/10-fiches.jpg){w=5.4}

**Suivi des cultures.** L'onglet « Cultures » affiche l'exploitation de l'utilisateur : nombre de cultures, surface totale, prochaine récolte, puis une carte par culture avec sa photographie, son avancement et le nombre de jours avant la récolte. La page d'une culture propose quatre gestes illustrés (arroser, engrais, traiter, récolter), le cycle cultural avec ses dates et l'enregistrement d'une récolte, qui alimente automatiquement le stock.

!![Mes cultures et détail d'une culture](figures/08-cultures.jpg|figures/09-detail-culture.jpg){w=5.4}

**Mon exploitation : trésorerie, ventes, stocks et dépenses.** Le tableau de bord « Mon exploitation » donne la trésorerie nette, les recettes et dépenses, la valeur indicative du stock et des opportunités de marché. La vente d'un produit en stock se fait avec un pavé numérique et un total calculé en direct ; le stock est décompté automatiquement et une vente supérieure au stock est refusée. La page Finances liste les recettes et dépenses, y compris celles qui proviennent des activités de culture.

!![Tableau de bord, vente, stock et finances](figures/11-dashboard.jpg|figures/12-vente.jpg|figures/13-stock.jpg|figures/14-finances.jpg){w=3.6}

**Marchés et itinéraire.** L'onglet « Marchés » affiche une carte du Sénégal avec les marchés regroupés par proximité et le prix du produit choisi, puis une liste classée (prix haut, prix bas, plus proches). La page d'un marché indique s'il est ouvert, ses horaires indicatifs, la date de la dernière mise à jour des prix, ses produits phares et, pour chacun, l'évolution sur 30 jours. La section « Pour y aller » donne le temps et la distance en voiture et à pied et trace le trajet sur la carte. La carte reste toujours en mode clair, y compris en mode sombre, pour sa lisibilité.

!![Carte des marchés, page d'un marché et itinéraire](figures/15-carte-marches.jpg|figures/16-page-marche.jpg|figures/17-itineraire.jpg){w=4.9}

**L'assistant Naatal IA.** L'écran de l'assistant présente des questions suggérées illustrées, un champ de saisie avec photo et microphone, et des réponses étiquetées « Fiches vérifiées », avec la source citée, un bouton d'écoute et des questions de suite. Pendant que l'utilisateur parle, sa phrase apparaît en direct.

!![Assistant Naatal IA, profil et choix de l'apparence](figures/18-assistant.jpg|figures/19-profil.jpg|figures/20-apparence.jpg){w=4.9}

**Mode sombre.** Toute l'application peut être affichée en mode sombre (choix « Clair », « Sombre » ou « Automatique »), à l'exception de la carte, volontairement conservée claire.

!![Mode sombre : accueil et tableau de bord](figures/21-accueil-sombre.jpg|figures/22-dashboard-sombre.jpg){w=5.4}

[À COMPLÉTER : captures supplémentaires à prendre sur un téléphone réel : saisie vocale en cours, proposition d'action de l'assistant avec confirmation, diagnostic d'une photo de plante, notifications, rappels, installation sur l'écran d'accueil.]

**L'assistant Naatal IA** concentre les choix de conception les plus importants.

*Chaîne de traitement d'une question agronomique.*

1. L'application envoie la question et les derniers échanges de la conversation (huit messages au plus).
2. Le serveur **détecte la culture et le sujet** (semis, fertilisation, maladies, eau, récolte, rendement, cycle) en s'appuyant sur les noms de la fiche et leurs alias. Si la question seule ne désigne aucune culture (« et pour l'engrais ? »), il utilise les messages précédents pour la retrouver.
3. Il **extrait de la base les rubriques correspondantes**, avec leurs sources numérotées.
4. Il demande au modèle de langage de rédiger une **réponse courte** en n'utilisant que ces fiches, en citant au moins une source, et en terminant par deux ou trois **questions suggérées**.
5. Il **valide** la réponse : toute citation dont le numéro ne correspond à aucune source est supprimée ; une réponse sans aucune citation valide est rejetée et remplacée par un résumé construit directement depuis les fiches.
6. Il **signale ce qui manque** (« information non disponible dans nos fiches vérifiées ») et, si une source vient d'ailleurs qu'un référentiel sénégalais, ajoute un avertissement.
7. À défaut de fiche sur le sujet, la réponse est un **conseil général clairement étiqueté** comme non issu des fiches vérifiées, à confirmer auprès d'un conseiller.

*Évolutions issues de retours d'usage.* Une première version renvoyait, pour la question « je veux cultiver les patates douces », la fiche complète d'un seul bloc : l'assistant était exact mais inutilisable pour un producteur pressé. Il a été refondu : réponses d'environ soixante mots, puces, questions suggérées, repères de citation masqués dans le texte (les sources restent accessibles par un bouton). Plus tard, lors de l'essai de l'application, plusieurs défauts ont été relevés et corrigés : une demande d'action (« j'ai dépensé 5 000 francs ») recevait une fiche de culture au lieu d'une action ; l'assistant a été doté d'un planificateur à outils et d'une réponse honnête (« je ne peux pas faire cela, mais je peux… ») lorsqu'une demande sort de ses capacités. La météo posée à l'assistant, d'abord approximative, utilise désormais la vraie météo de la zone de l'utilisateur ou déclare ne pas la connaître.

*Disponibilité.* Un incident a montré la nécessité d'un mode dégradé : le modèle utilisé par défaut a été retiré par le fournisseur pour les nouveaux comptes. Le mode de repli a bien fonctionné (l'utilisateur obtient toujours une réponse sourcée depuis les fiches), mais l'incident a conduit à changer de modèle, à ajouter une bascule automatique entre deux fournisseurs, à rendre le nom du modèle configurable et à tenir un journal d'usage.

### Sous-section 2 : Synthèse et discussion des résultats

**Tests exécutés.** Les résultats suivants ont été obtenus le 30 octobre 2026 sur le poste de développement, dans le cadre de l'audit de fin de projet.

Table: Vérifications exécutées et résultats

| Vérification | Commande | Résultat |
|---|---|---|
| Contrôle du projet | `python manage.py check` | 0 problème |
| Migrations | `python manage.py makemigrations --check --dry-run` | aucune migration oubliée |
| Configuration de production | `python manage.py check --deploy --settings=core.settings.prod` | 1 avertissement mineur (préchargement HSTS) |
| Tests du serveur | `python manage.py test` | **768 tests réussis** |
| Analyse statique mobile | `flutter analyze lib` | 0 erreur ; 8 remarques d'import inutile |
| Tests mobile | `flutter test` | **245 tests réussis** |

Le code du projet représente environ 38 500 lignes de Dart pour l'application et 12 300 lignes de Python (hors tests) pour le serveur. [À COMPLÉTER : taux de couverture de tests mesuré par le pipeline d'intégration continue.]

**Sécurité.** Des audits successifs ont mis en évidence puis fait corriger des défauts, verrouillés par des tests :

- des ressources privées accessibles par simple identifiant (référence directe non sécurisée) : l'accès est désormais filtré par propriétaire et des tests d'accès croisé vérifient chaque ressource, y compris les signalements de ravageurs, corrigés en fin de projet ;
- un chemin d'exécution de requêtes SQL construites à partir de texte libre dans l'assistant : il a été supprimé ;
- l'absence de limites contre les abus : des limites de débit protègent la connexion, l'assistant et la voix ;
- l'absence de politique de mot de passe, de validation du numéro et d'invalidation des jetons : ils ont été ajoutés ;
- l'absence de droits sur les données : une politique de confidentialité versionnée, un export complet et une suppression de compte sont disponibles ;
- des fuites de données entre comptes côté application (un nouveau compte retrouvait la culture d'un compte précédent) : la session est désormais cloisonnée et un test dédié le vérifie.

**Performance.** La mesure a révélé des requêtes « N+1 » : pour 300 cultures, la liste des cultures exécutait 301 requêtes SQL, la liste des ventes 301 et l'export des données 310. Après correction (chargement groupé des activités et du nom de la culture), ces points d'accès exécutent respectivement 2, 1 et 10 requêtes, indépendamment du volume. Ces temps absolus ne se transposent pas à un serveur de production (mesures faites avec SQLite et le client de test) ; **le nombre de requêtes est l'indicateur fiable**, et un test automatique échoue désormais si un point d'accès redevient N+1.

**Résilience.** Les écritures effectuées sans réseau sont placées dans une file locale et rejouées au retour de la connexion ; les cultures sont mises en cache localement pour la lecture, par compte, avec une expiration et une purge à la déconnexion.

**Audit technique de fin de projet.** L'audit du 30 octobre 2026 conclut à un état de **fusion possible sous conditions** et à un état **non prêt pour la production**.

Table: Principaux constats de l'audit de fin de projet

| Réf. | Gravité | Constat | Correction recommandée |
|---|---|---|---|
| A1 | P0 (production) | Le code de vérification d'inscription vaut « 1234 » par défaut dans la configuration, et aucune garde ne l'interdit en production | Valeur vide par défaut, refus de démarrer en production s'il est défini, passerelle SMS réelle |
| A2 | P1 (fusion) | Travail récent non commité au moment de l'audit | Commité et poussé sur la branche de test le 30 octobre 2026 |
| A3 | P1 (fusion) | La branche principale distante a un commit d'avance, avec un conflit prévisible dans le fichier de présentation | Intégrer la branche principale et résoudre le conflit |
| A4 | P1 (production) | Configuration HTTPS rédigée mais non testée sur un serveur ; durée HSTS de 1 heure | Tester sur un serveur réel, puis allonger la durée |
| A5 | P1 (production) | Limites de débit réelles non mesurées sous charge | Mesurer sous charge |
| A6 | P2 | Huit points d'accès publics (marchés, authentification, confidentialité) | Relecture ciblée |
| A7 | P2 | Numéro de support fictif ; 23 cultures sans fiche sourcée | Renseigner un vrai contact ; compléter les fiches |
| A8 | P2 | Services publics de cartes et d'itinéraires sans garantie de service | Passer à un service sous contrat avant un vrai trafic |
| A9 | P3 | Huit remarques d'analyse statique (imports inutiles) | Les retirer |

**Discussion par rapport aux hypothèses.**

Table: Verdict sur les hypothèses de recherche

| Hypothèse | Verdict | Éléments |
|---|---|---|
| H1 : réponses sourcées et aveu d'ignorance réduisent le risque d'erreur | **Confirmée sur le plan technique** | Tests de citation, de rejet des citations inventées et de signalement des manques ; mode de repli depuis les fiches. Elle ne garantit pas l'exactitude des fiches elles-mêmes (sources parfois anciennes) |
| H2 : réponses courtes, questions suggérées et voix adaptées au producteur | **Non démontrée** | Conception et corrections issues d'essais ; aucune mesure auprès d'utilisateurs : validation terrain prévue |
| H3 : confirmation et validation par le code suffisent à autoriser l'autonomie | **Confirmée sur le périmètre testé** | Tests de l'agent avec un modèle simulé (outil inconnu refusé, ressource d'autrui refusée, aucune écriture sans confirmation) ; comportement avec le vrai modèle observé seulement sur des cas d'essai |
| H4 : isolation serveur suffisante | **Confirmée sur le périmètre testé** | Tests d'accès croisé sur chaque ressource privée ; non équivalent à un audit externe |
| H5 : file et cache rendent l'application utilisable hors connexion | **Partiellement confirmée** | File d'attente testée ; cache de lecture limité à certaines données |

**Limites et éléments simulés (en toute transparence).**

- La **vérification du numéro par SMS** n'est pas branchée à une passerelle : l'inscription utilise un code de démonstration (voir A1) et aucun SMS n'est envoyé.
- Les **prix de marché** sont des données d'amorçage générées, et non un flux réel.
- L'**assistant autonome** est validé par des tests avec un modèle simulé ; son comportement avec le vrai modèle reste à éprouver sur un plus grand nombre de cas.
- La **saisie vocale en direct** n'a pas été vérifiée sur un téléphone réel ni sur l'application installée sur l'écran d'accueil d'un iPhone.
- Le **mode sombre** couvre l'ensemble des écrans principaux ; certains écrans anciens n'ont pas fait l'objet d'une vérification visuelle une à une.
- La **langue** : l'application est en français ; le wolof est annoncé comme non encore disponible.
- La **lecture hors ligne** ne couvre qu'une partie des données.
- **Production** : base PostgreSQL, sauvegardes, configuration HTTPS, signature de publication de l'application Android et suivi des plantages ne sont pas encore éprouvés. [À COMPLÉTER : état exact de chacun de ces éléments.]
- Quelques **défauts visuels connus** : certaines cultures (bissap, maïs) n'ont pas encore leur photographie dans le catalogue de choix, et un conseil météo peut annoncer de la pluie « bientôt » alors que la journée est sèche.
- Aucune **évaluation auprès d'utilisateurs** n'a encore été conduite.

### Sous-section 3 : Recommandations

*Pour la suite du projet, par ordre de priorité.*

1. **Corriger le défaut P0 avant toute mise en ligne** : code de vérification par défaut, puis intégrer une passerelle SMS (génération et expiration du code, limite de tentatives et d'envois, jamais de code dans une réponse de l'API).
2. **Valider sur le terrain** avec des producteurs et des conseillers, selon le protocole décrit au chapitre III, et ajuster les réponses de l'assistant et les écrans.
3. **Brancher une source de prix réelle** (observatoires de marché ou collecte participative) et indiquer la date de chaque prix.
4. **Actualiser et élargir les fiches** avec l'appui de l'ANCAR, de l'ISRA et de la SAED ; documenter les 23 cultures sans fiche sourcée ; remplacer les sources anciennes par des références récentes.
5. **Introduire une langue nationale** (wolof) et des voix adaptées, pour les utilisateurs qui ne lisent pas le français.
6. **Préparer la mise en production** : PostgreSQL, restauration de sauvegarde réellement testée, HTTPS vérifié sur serveur, signature de publication Android, suivi des plantages, déploiement automatique.
7. **Étendre le cache hors ligne** à l'ensemble des listes et ajouter un test de bout en bout de l'application vers le serveur.
8. **Compléter le cadre juridique** : identité du responsable de traitement, validation du texte de la politique de confidentialité, démarches auprès de la CDP.

*Pour la gouvernance des contenus.* Maintenir la règle « base d'abord » : toute extension de l'assistant vers le web ne doit passer que par des domaines de confiance et une validation humaine avant intégration aux fiches.

---

# Conclusion générale

Ce travail visait à concevoir une application mobile utile et honnête pour le producteur sénégalais, y compris celui qui lit peu. Naatal Agro réunit dans une application unique le suivi de l'exploitation (cultures, ventes, dépenses, stocks), l'information de contexte (calendrier agricole, marchés avec itinéraire, météo locale) et un assistant conversationnel utilisable à la voix, qui répond d'abord à partir de **fiches agronomiques sourcées**, déclare ce qu'il ne sait pas, tient compte de la conversation, propose la suite et n'agit dans l'exploitation qu'après une confirmation explicite. Les choix de sécurité (isolation des données, jetons tournants, limitation des abus, droits sur les données personnelles), de résilience (file hors ligne, cache de lecture) et de performance (suppression des requêtes redondantes, mesure automatisée) ont été vérifiés par des tests et non par de simples affirmations : 768 tests côté serveur et 245 côté mobile passent à la date du 30 octobre 2026.

Les résultats confirment techniquement la fiabilité de la chaîne de réponse (hypothèse H1), la sûreté de l'autonomie encadrée de l'assistant sur le périmètre testé (H3), l'isolation des données (H4) et en partie la résilience hors ligne (H5). L'adéquation des réponses courtes et de la voix au besoin réel des producteurs (H2) reste à démontrer sur le terrain. Le projet présente aussi des limites que ce mémoire a énoncées sans détour : un code de vérification de démonstration à neutraliser avant la production, des prix de marché d'amorçage, des sources parfois anciennes, une saisie vocale à éprouver sur téléphone réel et l'absence d'évaluation auprès d'utilisateurs.

Les perspectives sont claires : correction des points bloquants pour la production, validation terrain, prix réels, enrichissement des contenus avec les institutions agricoles, introduction d'une langue nationale, puis, dans des phases ultérieures, des services de mise en relation commerciale. Au-delà du produit, ce projet nous a appris qu'en agriculture comme ailleurs, **la confiance se construit sur la transparence** : une application qui dit « je ne sais pas, voici qui consulter » est plus utile qu'une application qui répond toujours.

---

# Webographie

Les références ci-dessous sont celles que nous avons utilisées pour rédiger ce mémoire. [À COMPLÉTER : ajouter pour chaque ligne la date de consultation, et ouvrir chaque lien pour vérifier son contenu avant le dépôt.]

- Africa Check, « Non, le secteur agricole n'emploie pas 70 % de la population sénégalaise », https://africacheck.org/fr/fact-checks/articles/non-le-secteur-agricole-nemploie-pas-70-de-la-population-senegalaise
- AllAfrica, « Sénégal : Création de richesse au Sénégal, le secteur primaire représente 16,3 % du PIB en 2022 », 2024, https://fr.allafrica.com/stories/202410090632.html
- Direction générale du Trésor, « Sénégal : agriculture et politique agricole », 2025, https://www.tresor.economie.gouv.fr/Articles/2025/06/01/senegal-agriculture-et-politique-agricole
- Osiris, « Le taux de pénétration de l'internet au Sénégal atteint 112,42 % en 2024 » (d'après l'ARTP), https://osiris.sn/le-taux-de-penetration-de-l-internet-au-senegal-atteint-112-42-en-2024.html
- République du Sénégal, « Loi n° 2008-12 du 25 janvier 2008 portant sur la protection des données à caractère personnel », https://www.wipo.int/wipolex/edocs/lexdocs/laws/fr/sn/sn009fr.pdf
- FAO, « FAO Crop Calendar : Sénégal », 2021, https://cropcalendar.apps.fao.org/#/home?id=SN
- ISRA, FAO et CDH, « La culture des agrumes au Sénégal (RADHORT) », 2012, https://www.fao.org/3/az822f/az822f.pdf
- CIRAD, « Le système sociotechnique associé à la mangue au Sénégal : pré-diagnostic », 2017, https://agritrop.cirad.fr/592209/1/Pre%CC%81diagnostic%20Mangue%20Se%CC%81ne%CC%81gal%20V4.pdf
- CGIAR Platform for Big Data in Agriculture, « Plant disease diagnosis using artificial intelligence: a case study on Plantix », https://bigdata.cgiar.org/digital-intervention/plant-disease-diagnosis-using-artificial-intelligence-a-case-study-on-plantix/
- GSMA, « Detecting and managing crop pests and diseases with AI: Insights from Plantix », https://www.gsma.com/solutions-and-impact/connectivity-for-good/mobile-for-development/programme/agritech/detecting-and-managing-crop-pests-and-diseases-with-ai-insights-from-plantix/
- Sources des fiches agronomiques : ISRA, CIRAD, SAED, ministère de l'Agriculture et de l'Équipement rural, Université Gaston Berger, CERAAS-UCAD (titres, années et liens dans le fichier `backend/apps/agriculture/data/agronomic_guides.json` du dépôt).
- Documentation technique : Flutter (https://docs.flutter.dev), Django (https://docs.djangoproject.com), Django REST Framework (https://www.django-rest-framework.org), Riverpod (https://riverpod.dev), Open-Meteo (https://open-meteo.com), OSRM (https://project-osrm.org), OpenStreetMap (https://www.openstreetmap.org/copyright), CARTO (https://carto.com/basemaps).
- Dépôt du projet : https://github.com/lansanacoly7/Naatal_Agro

---

# Annexes

## Annexe A : Dépôt, installation et lancement

[À COMPLÉTER : procédure d'installation du serveur (variables d'environnement, migrations, chargement des données de référence) et de l'application (compilation, lancement), à partir du fichier README du dépôt, testée sur une machine vierge.]

## Annexe B : Liste des points d'accès de l'interface de programmation

[À COMPLÉTER : tableau des points d'accès (méthode, chemin, rôle, authentification requise), à générer à partir du code du serveur ou de la collection Postman du dépôt (dossier `docs/postman`).]

## Annexe C : Politique de confidentialité et consentement

[À COMPLÉTER : texte de la politique de confidentialité affichée à l'utilisateur, après validation juridique.]

## Annexe D : Résultats détaillés de l'audit du 30 octobre 2026

[À COMPLÉTER : joindre le rapport d'audit complet (état Git, tests, sécurité, plan de correction) si l'encadrant le souhaite.]

## Annexe E : Guide d'entretien et résultats de la validation terrain

[À COMPLÉTER : guide d'entretien, effectifs, résultats et verbatims, une fois la validation terrain réalisée.]
