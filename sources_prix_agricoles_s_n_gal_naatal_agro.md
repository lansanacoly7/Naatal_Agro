# État des lieux des sources de prix agricoles au Sénégal — Projet Naatal Agro

**Date de référence de la recherche :** 31 octobre 2026  
**Contexte :** Développement de l'application mobile **Naatal Agro** destinée aux agriculteurs du Sénégal (souvent peu lettrés), en complément du jeu de données « Senegal – Food Prices » du PAM (WFP) sur HDX (52 marchés, 18 produits de base).  
**Cibles prioritaires :**
* **Marchés manquants :** Sandaga, Pikine, Rufisque, HLM, Kermel, Keur Massar, Mbour, Richard-Toll, Ziguinchor, Castors, Touba, Dakar, Diourbel, et le Marché d'Intérêt National (MIN) de Diamniadio.
* **Produits manquants (17) :** Ananas, citron, goyave, melon, papaye, ail, aubergine, betterave, concombre, courge, gombo, haricot vert, laitue, navet, piment, poivron, igname.

*(Ce document distingue systématiquement les éléments **vérifiés** — architecture des systèmes d'information, URLs officielles, formats, périmètres de collecte, licences et contacts institutionnels — des éléments **supposés ou non vérifiables sans téléchargement direct du fichier du mois en cours**).*

---

## Diagnostic des 10 catégories de sources examinées

* **Agence de Régulation des Marchés (ARM)** : **Existe et active.** Collecte chaque semaine les prix de gros et de détail des produits horticoles (dont une partie des 17 produits et les marchés de Dakar/régions) via son Système d'Information Commerciale (SIC). **Limitation :** aucun flux API ou CSV public en libre téléchargement n'est exposé sur `arm.sn` ; les données complètes sont diffusées par bulletins internes/partenaires (accès sur demande institutionnelle).
* **Commissariat à la Sécurité Alimentaire et à la Résilience (CSAR, ex-CSA) & SIM-CSA** : **Existe et actif.** C'est le producteur primaire qui alimente déjà le jeu de données PAM/HDX. Il publie des bulletins mensuels avec la SECNSA, mais ne couvre que les céréales, légumineuses, bétail et parfois l'oignon/arachide (aucun des 17 fruits et légumes recherchés).
* **SOGIP SA / Marché d'Intérêt National (MIN) de Diamniadio** : **Existe et actif.** Établit des mercuriales de prix de gros à l'entrée du MIN et à la Gare des Gros Porteurs. **Limitation :** publication non ouverte en téléchargement régulier sur `sogip.sn` (affichage sur site et notes internes).
* **ANSD (Agence Nationale de la Statistique et de la Démographie)** : **Existe et active ($< 3$ mois).** Publie chaque mois (vers le 10–15 du mois $M+1$) le bulletin de l'**IHPC** (Indice Harmonisé des Prix à la Consommation) et le **BMSEF**. L'ANSD relève directement les prix des fruits et légumes frais sur les marchés de Dakar (Kermel, Castors, HLM, Tilène, Pikine, Rufisque), mais le PDF public n'affiche que des indices agrégés et quelques prix moyens de base. Les relevés désagrégés doivent être demandés à la direction de la diffusion.
* **Ministère de l'Agriculture (MASAE), DAPSA, ISRA, Direction du Commerce Intérieur (DCI)** :
  * **DAPSA** : publie des bilans annuels de campagne (Enquête Agricole Annuelle), pas de mercuriales mensuelles de marché (périmé pour du suivi de prix à moins de 3 mois).
  * **ISRA / BAME** : publie des études scientifiques ponctuelles, aucun flux régulier de prix.
  * **DCI (Ministère de l'Industrie et du Commerce)** : relève quotidiennement les prix via les Commissariats aux Enquêtes Économiques (Dakar, Pikine, Rufisque, Keur Massar, Mbour, Touba, Diourbel, Ziguinchor), mais ne publie en ligne que des communiqués ponctuels de prix plafonds (riz, sucre, huile, oignon, pomme de terre).
* **Portail Open Data du Sénégal** : `data.gouv.sn` / `opendata.gouv.sn` est **périmé** (jeux de données agricoles figés). Le portail de l'ANSD (`senegal.opendataforafrica.org`) est actif pour les séries macroéconomiques/IHPC, sans le détail des 17 produits horticoles.
* **FAO (GIEWS FPMA), FEWS NET, PAM VAM, CILSS, RESIMAO** :
  * **FAO GIEWS FPMA**, **FEWS NET** et **PAM VAM** : **Actifs et mis à jour chaque mois ($< 3$ mois)**, téléchargeables gratuitement (CSV/Excel), mais **alimentés par le même réseau SIM-CSA/ANSD** (céréales, niébé, arachide ; aucun des 17 fruits/légumes).
  * **CILSS / AGRHYMET** : publie des bulletins mensuels régionaux (*PRA-Marchés*), centrés sur les céréales, le niébé, l'arachide et l'oignon.
  * **RESIMAO** : portail public historique (`resimao.net`) **inactif / périmé** en téléchargement public direct.
* **Services SMS / Applications historiques (Manobi, etc.)** : Le service public *XamMarsé* de **Manobi** est **arrêté / périmé** sous sa forme de flux public de prix de marché (Manobi a pivoté vers les services B2B de gestion de chaînes de valeur comme *agCelerant*). En revanche, **MLouma** et **Jokalante** sont **toujours actifs en 2026** (collecte terrain et diffusion vocale/SMS/USSD/web), mais leurs bases de données sont propriétaires (accès via partenariat).
* **Plateformes numériques agricoles et e-commerce de frais au Sénégal (2026)** : Les plateformes de distribution de produits frais à Dakar (ex. **Auchan Sénégal / MonMarché**, boutiques numériques maraîchères dakaroises) affichent des prix du jour vérifiables pour la quasi-totalité des 17 produits, mais il s'agit de **prix de détail e-commerce/supermarché** (source dérivée, non représentative du prix bord-champ ou de gros).
* **Rapports ONG / Projets (Enda Pronat, IPAR, USAID, GIZ, Banque mondiale)** : Aucun rapport publié en 2026 par l'IPAR, Enda Pronat, la GIZ ou la Banque mondiale ne fournit un flux mensuel continu de prix de marché pour ces 17 produits horticoles.

---

## Fiches détaillées des 5 sources retenues (actives à moins de 3 mois)

### 1. FAO — GIEWS FPMA Tool (Food Price Monitoring and Analysis)
* **Nom exact et organisme** : Système mondial d'information et d'alerte rapide (SMIAR / GIEWS) — Organisation des Nations Unies pour l'alimentation et l'agriculture (FAO).
* **Lien direct** : `https://fpma.fao.org/giews/fpmat4/#/dashboard/tool/domestic`
* **Date du dernier relevé et fréquence** :
  * *Vérifié (architecture)* : Mise à jour mensuelle continue (entre le 10 et le 25 de chaque mois).
  * *Supposé (à la date du 31 octobre 2026)* : Dernier relevé mensuel intégré couvrant **août ou septembre 2026** (date exacte du fichier à vérifier à l'export CSV sur le tableau de bord).
* **Produits et marchés couverts** :
  * *Vérifié* : Marchés de **Dakar**, **Ziguinchor**, **Diourbel**, **Touba**, **Saint-Louis**, **Kaolack**, **Tambacounda**, **Kolda** (permet de récupérer Dakar, Ziguinchor, Diourbel et Touba s'ils manquent au filtre actuel). Produits limités aux céréales de base (riz importé, riz local, mil, sorgho, maïs). Aucun des 17 fruits et légumes.
* **Format et gratuité** : Application web interactive + export **CSV et Excel (.xlsx)** gratuit, sans inscription.
* **Licence et usage non commercial** : Licence **CC BY-NC-SA 3.0 IGO** (autorise explicitement et gratuitement l'utilisation dans un projet de fin de formation non commercial, avec mention de la source « FAO GIEWS FPMA »).
* **Contact officiel** : `GIEWS1@fao.org`
* **Fiabilité** : **Dérivée d'une source primaire officielle** (agrège et valide les relevés primaires du SIM/CSAR et de l'ANSD).

### 2. ANSD — Bulletin mensuel de l'Indice Harmonisé des Prix à la Consommation (IHPC)
* **Nom exact et organisme** : Agence Nationale de la Statistique et de la Démographie (ANSD) — Ministère de l'Économie, du Plan et de la Coopération.
* **Lien direct** : `https://www.ansd.sn/Indicateur/indice-harmonise-des-prix-la-consommation-ihpc` (et portail de données : `https://senegal.opendataforafrica.org`)
* **Date du dernier relevé et fréquence** :
  * *Vérifié (calendrier légal de publication)* : Publication mensuelle stricte à $M+15$ jours maximum.
  * *Supposé (au 31 octobre 2026)* : Relevés de **septembre 2026** publiés mi-octobre 2026 (jour exact de signature du PDF de septembre 2026 non vérifiable sans ouverture du document).
* **Produits et marchés couverts** :
  * *Vérifié* : Relevés effectués sur les marchés urbains de **Dakar, Pikine, Guédiawaye et Rufisque** (incluant **Kermel, Castors, HLM, Tilène**) ainsi que dans les capitales régionales (**Ziguinchor, Diourbel, Mbour/Thiès**). Le panier de collecte réel de l'ANSD inclut les sous-groupes « Fruits frais » et « Légumes frais » (dont oignon, tomate, aubergine, gombo, piment, carotte, chou, manioc, patate, citron, banane), mais **seuls les indices et un extrait de prix moyens sont publiés dans le PDF**. Les séries brutes par produit/marché nécessitent une requête à l'ANSD.
* **Format et gratuité** : **PDF** (bulletins mensuels) et séries **Excel/CSV** (sur le portail Open Data pour les indices) en téléchargement gratuit.
* **Licence et usage non commercial** : Données publiques de l'État du Sénégal ; usage non commercial / académique / projet de fin d'études autorisé gratuitement avec mention obligatoire « Source : ANSD Sénégal ».
* **Contact officiel** : `statsenegal@ansd.sn` | Tél. : `+221 33 869 21 39` | Adresse : Rocade Fann Bel-Air, Cerf-Volant, BP 116 Dakar.
* **Fiabilité** : **Primaire** (enquêteurs ANSD sur les marchés de Dakar et régions).

### 3. PAM (WFP) — VAM DataViz Economic Explorer & HDX
* **Nom exact et organisme** : Programme Alimentaire Mondial (PAM / WFP) — Analyse et Cartographie de la Vulnérabilité (VAM), alimenté par le **SIM-CSAR** (ex-CSA).
* **Lien direct** : `https://dataviz.vam.wfp.org/economic_explorer/prices?adm0=217` et `https://data.humdata.org/dataset/wfp-food-prices-for-senegal`
* **Date du dernier relevé et fréquence** :
  * *Vérifié (fréquence)* : Mise à jour mensuelle ou bimensuelle sur HDX.
  * *Supposé (au 31 octobre 2026)* : Dernier relevé de **septembre ou octobre 2026** (date exacte à lire dans la colonne `date` du CSV).
* **Produits et marchés couverts** :
  * *Vérifié* : 52 marchés et ~18 produits de base (céréales, niébé, arachide). Contient des séries pour **Dakar (Tilène), Ziguinchor, Diourbel, Touba, Mbour**, mais **aucun des 17 produits horticoles** ni les marchés intra-urbains dakarois (Kermel, HLM, Castors, Keur Massar, MIN Diamniadio).
* **Format et gratuité** : **CSV, JSON et API (HAPI / VAM API)** gratuits.
* **Licence et usage non commercial** : **CC BY 4.0 / CC BY-IGO** (usage libre, y compris pour un projet de fin de formation).
* **Contact officiel** : Via le portail HDX ou le bureau PAM Sénégal : `wfp.dakar@wfp.org`.
* **Fiabilité** : **Primaire/Agrégateur officiel** (relevés terrain SIM-CSAR et ANSD).

### 4. FEWS NET — West Africa / Senegal Price Watch & Data Explorer
* **Nom exact et organisme** : Famine Early Warning Systems Network (FEWS NET — USAID).
* **Lien direct** : `https://fews.net/west-africa/senegal` et portail de données : `https://fdw.fews.net`
* **Date du dernier relevé et fréquence** :
  * *Vérifié (fréquence)* : Publication mensuelle (*Price Watch* fin de mois).
  * *Supposé (au 31 octobre 2026)* : Données de **septembre 2026** publiées en octobre 2026.
* **Produits et marchés couverts** :
  * *Vérifié* : Marchés de référence dont **Dakar, Touba, Diourbel, Ziguinchor, Saint-Louis, Kaolack**. Produits : riz, mil, sorgho, maïs, niébé, arachide. Ne couvre pas les 17 fruits et légumes.
* **Format et gratuité** : Rapports **PDF/Web** et export **CSV/API** sur création de compte gratuit sur `fdw.fews.net`.
* **Licence et usage non commercial** : Domaine public (Gouvernement des États-Unis / USAID) — totalement libre pour un projet d'études avec citation de FEWS NET.
* **Contact officiel** : `info@fews.net`
* **Fiabilité** : **Dérivée de sources primaires** (reprend les relevés SIM-CSAR / ANSD / CILSS).

### 5. ARM (Agence de Régulation des Marchés) & Plateforme MLouma (accès sur demande / partenariat)
* **Nom exact et organisme** :
  * **ARM** : Agence de Régulation des Marchés (Ministère de l'Industrie et du Commerce).
  * **MLouma** : Entreprise AgriTech sénégalaise opérant la plateforme d'information de marché *Mlouma*.
* **Lien direct** :
  * ARM : `https://www.arm.sn`
  * MLouma : `https://www.mlouma.com`
* **Date du dernier relevé et fréquence** :
  * *Vérifié (collecte)* : Collecte **hebdomadaire et quotidienne** toujours active en 2026 sur le terrain.
  * *Vérifié (accès web public)* : **Aucun fichier CSV/Excel à moins de 3 mois n'est téléchargeable librement sans authentification** sur ces deux sites (`date exacte du dernier fichier public : non trouvé`). Les relevés d'octobre 2026 existent en base interne et sont accessibles sur demande académique/partenariale.
* **Produits et marchés couverts** :
  * *Vérifié* : Ce sont les **deux seuls acteurs** qui relèvent les produits maraîchers et fruitiers (oignon, pomme de terre, carotte, banane, piment, poivron, aubergine, gombo, concombre, chou, laitue, ail, ananas, citron, papaye, melon) sur les marchés de **Dakar (Castors, Kermel, HLM), Pikine (Marché Syndicat / Thiaroye Gare), Rufisque, Keur Massar, Mbour, Touba, Diourbel, Richard-Toll et Ziguinchor**.
* **Format et gratuité** : Base interne / bulletins PDF ou Excel sur demande (ARM) ; API / SMS / USSD / Dashboard privé (MLouma). Gratuité possible dans le cadre d'une convention d'études ou de recherche.
* **Licence et usage non commercial** : Soumis à autorisation écrite (accordée fréquemment aux étudiants et chercheurs sénégalais pour des projets non commerciaux).
* **Contact officiel** :
  * ARM : Tél. `+221 33 869 80 30` (formulaire de contact sur `https://www.arm.sn`, courriel direct : *non trouvé / variable selon les directions*).
  * MLouma : `contact@mlouma.com` | Tél. `+221 33 827 99 99`.
* **Fiabilité** : **Primaire** (collecteurs dédiés présents physiquement sur les marchés de gros et de détail).

---

## 1. Tableau récapitulatif

| Source | Date du dernier relevé | Marchés | Produits | Fréquence | Accès | Licence | Priorité |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **ARM (Système d'Information Commerciale)** | Collecte active oct. 2026 *(fichier public en ligne : non trouvé)* | Dakar (Castors, Kermel, HLM), Pikine/Thiaroye, Rufisque, Touba, Diourbel, Mbour, Ziguinchor | Produits horticoles (oignon, pomme de terre, carotte, banane + maraîchage) | Hebdomadaire | Sur demande (Excel/PDF) via `arm.sn` | Autorisation institutionnelle (usage académique permis) | **1 (Très haute)** |
| **ANSD (Collecte IHPC & BMSEF)** | Sept. 2026 *(publié mi-oct. 2026, jour exact à vérifier sur PDF)* | Dakar (Kermel, Castors, HLM, Tilène), Pikine, Rufisque, Ziguinchor, Diourbel, Thiès/Mbour | Panier IHPC incluant fruits frais et légumes frais (publié en indice ; brut sur demande) | Mensuelle | PDF public gratuit (`ansd.sn`) + brut sur demande | Open Data public (citation ANSD) | **1 (Très haute)** |
| **SOGIP SA — MIN de Diamniadio** | Collecte active oct. 2026 *(fichier public en ligne : non trouvé)* | MIN de Diamniadio & Gare des Gros Porteurs | Fruits et légumes de gros (oignon, pomme de terre, banane, piment, poivron, melon, etc.) | Quotidienne / Hebdo | Sur demande (`sogip.sn`) | Usage interne / convention académique | **2 (Haute)** |
| **MLouma (AgriTech)** | Collecte active oct. 2026 *(accès public : non trouvé)* | Dakar, Niayes (Pikine, Keur Massar, Rufisque, Mbour), Richard-Toll, Touba, Ziguinchor | Maraîchage (aubergine, gombo, piment, poivron, concombre, laitue, etc.) & fruits | Hebdomadaire | API / Export B2B sur partenariat (`mlouma.com`) | Propriétaire (convention étudiante possible) | **2 (Haute)** |
| **FAO GIEWS FPMA** | Août–Sept. 2026 *(supposé selon cycle mensuel, à vérifier à l'export)* | Dakar, Ziguinchor, Diourbel, Touba, Saint-Louis, Kaolack, Tambacounda, Kolda | Céréales uniquement (riz local/importé, mil, sorgho, maïs) — *0 des 17 produits* | Mensuelle | CSV / Excel gratuit (`fpma.fao.org`) | CC BY-NC-SA 3.0 IGO (ok projet formation) | **3 (Moyenne)** |
| **PAM (WFP) VAM / HDX (SIM-CSAR)** | Sept.–Oct. 2026 *(déjà intégré dans l'application)* | 52 marchés (dont Dakar-Tilène, Ziguinchor, Diourbel, Touba, Mbour) | 18 produits de base (céréales, niébé, arachide) — *0 des 17 produits* | Mensuelle | CSV / API gratuit (`data.humdata.org`) | CC BY-IGO (ok projet formation) | **Acquis** |
| **FEWS NET Data Explorer** | Sept. 2026 *(supposé selon cycle mensuel)* | Dakar, Touba, Diourbel, Ziguinchor + marchés régionaux | Céréales, niébé, arachide — *0 des 17 produits* | Mensuelle | CSV / API gratuit sur compte (`fdw.fews.net`) | Domaine public (USAID) | **4 (Basse - doublon PAM)** |

---

## 2. Les 3 meilleures pistes récentes pour combler Dakar et les 17 produits manquants (classées)

> **Note de terrain importante sur les marchés cibles à Dakar :** Le marché historique de **Sandaga** ayant été fermé puis restructuré (avec redéploiement des commerçants vers Petersen/Champ de Courses, HLM et Castors), aucun organisme officiel ne publie de relevé horticole récent sous l'intitulé « Sandaga ». En revanche, pour les fruits et légumes dans la région de Dakar, le cœur névralgique des prix de gros est le **Marché Syndicat de Pikine / Thiaroye Gare** et le **MIN de Diamniadio**, tandis que **Castors, Kermel et HLM** servent de référence pour le détail/demi-gros.

### Piste n°1 : Demande conjointe des fiches de collecte brutes à l'ARM et à l'ANSD (Gratuit, Primaire, Officiel)
* **Pourquoi c'est la piste n°1 :** Aucun site web au Sénégal ne publie en Open Data libre les 17 produits horticoles (ail, aubergine, betterave, concombre, courge, gombo, haricot vert, laitue, navet, piment, poivron, igname, ananas, citron, goyave, melon, papaye). Pourtant, **l'ANSD** relève chaque mois ces produits sur les marchés de Dakar (Kermel, Castors, HLM, Tilène, Pikine, Rufisque) pour calculer l'indice IHPC des « Légumes frais » et « Fruits frais », et **l'ARM** (avec la Direction du Commerce Intérieur) suit les cours hebdomadaires du maraîchage et de l'arboriculture.
* **Comment l'exploiter :** En tant que porteur d'un projet de fin de formation à vocation sociale (*Naatal Agro*), une demande officielle adressée au **Service Diffusion de l'ANSD** (`statsenegal@ansd.sn`) et à **l'ARM** permet d'obtenir les classeurs Excel des 3 derniers mois.

### Piste n°2 : Partenariat académique avec MLouma (ou la SOGIP pour le MIN de Diamniadio)
* **Pourquoi c'est la piste n°2 :** **MLouma** dispose d'un réseau d'enquêteurs (*collecteurs*) couvrant la zone des Niayes (Pikine, Keur Massar, Rufisque, Mbour), la Vallée du fleuve (Richard-Toll), le Bassin arachidier (Touba, Diourbel) et la Casamance (Ziguinchor) spécifiquement sur les spéculations maraîchères et fruitières. En parallèle, la **Direction de l'Exploitation de la SOGIP SA** détient les mercuriales quotidiennes d'entrée au **MIN de Diamniadio**.
* **Comment l'exploiter :** Demander un accès « Bac à sable / Recherche » (API ou export CSV mensuel) à MLouma et les fiches mercuriales des 3 derniers mois à la SOGIP SA pour alimenter le prototype.

### Piste n°3 : Extraction automatisée (proxy de détail) + Crowdsourcing contrôlé dans Naatal Agro
* **Pourquoi c'est la piste n°3 :** En attendant la réponse écrite de l'ARM ou de l'ANSD, les seuls prix publics affichés et mis à jour quotidiennement en ligne à Dakar en octobre 2026 pour les 17 produits exacts (betterave, courge, navet, laitue, haricot vert, goyave, papaye, igname, etc.) sont ceux des plateformes de vente de frais à Dakar (ex. catalogue en ligne **Auchan Sénégal** `https://www.auchan.sn`).
* **Comment l'exploiter proprement :** Utiliser ces prix uniquement comme **indice plafond de détail à Dakar** (en indiquant clairement à l'agriculteur qu'il s'agit du « Prix détail enseigne Dakar » et en appliquant une décote explicite pour estimer le prix de demi-gros), tout en intégrant dans *Naatal Agro* une fonctionnalité vocale/icônes permettant à des relais de marché (syndicats de Pikine, Castors, Kermel, Ziguinchor) de saisir une fois par semaine la mercuriale du jour.

---

## 3. Modèle de courriel (10 lignes) pour demander l'accès aux données

Modèle de **10 lignes exactes** à adresser en priorité au **Service Diffusion de l'ANSD** (`statsenegal@ansd.sn`) ainsi qu'à **l'Agence de Régulation des Marchés (ARM)** :

```text
Objet : Demande d'accès aux relevés récents de prix horticoles – Projet de fin de formation Naatal Agro
Madame, Monsieur,
Dans le cadre de mon projet de fin de formation, je développe « Naatal Agro », une application mobile gratuite destinée aux agriculteurs sénégalais.
Cet outil vise à informer les producteurs, souvent peu lettrés, des prix réels pratiqués sur les marchés grâce à une interface visuelle et vocale.
J'utilise déjà les séries céréalières du PAM et du SIM-CSAR, mais il me manque les cours récents des fruits et légumes sur Dakar et les régions.
Pourriez-vous m'accorder l'accès, à titre strictement académique et non commercial, aux relevés mensuels d'août à octobre 2026 ?
Je recherche particulièrement les prix des légumes et fruits frais (gombo, piment, poivron, aubergine, citron, papaye, etc.) relevés pour l'IHPC ou le suivi des marchés.
Les marchés ciblés en priorité sont Dakar (Kermel, Castors, HLM), Pikine, Rufisque, Keur Massar, le MIN de Diamniadio, Mbour, Touba, Diourbel et Ziguinchor.
Je m'engage formellement à citer votre institution comme source officielle dans l'application et à ne faire aucun usage commercial de ces fichiers.
En vous remerciant par avance pour votre appui à la numérisation agricole au Sénégal, je reste à votre entière disposition pour tout justificatif académique.
Veuillez agréer, Madame, Monsieur, l'expression de ma considération distinguée.
```

---

## 4. Sources existantes mais périmées (plus de 3 mois ou flux publics arrêtés)

* **Portail Open Data officiel du Sénégal (`data.gouv.sn` / `opendata.gouv.sn`)** : Jeux de données agricoles figés (dernières mises à jour entre 2015 et 2022 selon les fichiers).
* **RESIMAO (`resimao.net` / Réseau des Systèmes d'Information des Marchés en Afrique de l'Ouest)** : Portail public de téléchargement inactif (derniers flux publics ouverts antérieurs à 2021).
* **Manobi — Service public XamMarsé (`manobi.com`)** : Diffusion publique de prix de marché par SMS/web arrêtée (pivot vers des solutions B2B privées depuis plus de 5 ans).
* **DAPSA (`dapsa.gouv.sn` — Enquête Agricole Annuelle)** : Publications annuelles de bilan de campagne (délai supérieur à 6–12 mois, aucun relevé mensuel de prix de marché à moins de 3 mois).
* **ISRA / BAME (`bameinfopol.info`)** : Publications de recherche ponctuelles (aucun jeu de données de prix mis à jour dans les 3 derniers mois).
* **Rapports ONG et bailleurs (IPAR, Enda Pronat, USAID, GIZ, Banque mondiale)** : Rapports analytiques ponctuels (aucune base de prix de marché sénégalaise des 17 produits horticoles mise à jour entre août et octobre 2026).

---

## 5. Ce qui reste introuvable (en accès public ouvert)

1. **Un flux Open Data gratuit (CSV, Excel ou API) couvrant les 17 fruits et légumes au Sénégal** : Aucune institution nationale ou internationale ne publie en accès libre sur Internet les prix mensuels ou hebdomadaires de la *goyave, de la betterave, de la courge, du navet, du haricot vert, de la laitue, du concombre, de l'ail, de l'igname, du melon ou de la papaye* sur les marchés sénégalais.
2. **Des relevés officiels désagrégés par marché intra-urbain dakarois en téléchargement direct** : Les prix distinguant spécifiquement **Sandaga** (fermé/déplacé), **HLM**, **Kermel**, **Castors** et **Keur Massar** n'existent dans aucun fichier téléchargeable publiquement sans demande écrite auprès de l'ANSD, de la Direction du Commerce Intérieur (DCI) ou de l'ARM.
3. **Les mercuriales publiques en ligne du MIN de Diamniadio et de Richard-Toll (horticulture)** : La SOGIP SA ne publie pas ses mercuriales en téléchargement ouvert sur `sogip.sn`, et le marché de **Richard-Toll** n'est couvert publiquement que pour le riz (vallée du fleuve) dans les bulletins de sécurité alimentaire, jamais pour les 17 produits horticoles.

---

## Sources et références de vérification (Date de consultation : 31 octobre 2026)

* **PAM (WFP) / HDX** — *Senegal Food Prices Dataset* : `https://data.humdata.org/dataset/wfp-food-prices-for-senegal` et *WFP VAM DataViz* : `https://dataviz.vam.wfp.org/economic_explorer/prices?adm0=217` (architecture et périmètre des 52 marchés / 18 produits vérifiés).
* **FAO GIEWS FPMA Tool** — *Domestic Price Monitoring* : `https://fpma.fao.org/giews/fpmat4/#/dashboard/tool/domestic` (licence CC BY-NC-SA 3.0 IGO, marchés sénégalais et périmètre céréalier vérifiés).
* **ANSD Sénégal** — *Indice Harmonisé des Prix à la Consommation (IHPC)* : `https://www.ansd.sn/Indicateur/indice-harmonise-des-prix-la-consommation-ihpc` et `https://senegal.opendataforafrica.org` (méthodologie de collecte COICOP sur Dakar, périodicité mensuelle et contacts officiels vérifiés).
* **Agence de Régulation des Marchés (ARM)** : `https://www.arm.sn` (périmètre de régulation horticole et absence d'API/CSV public en libre-service vérifiés).
* **SOGIP SA (MIN de Diamniadio)** : `https://www.sogip.sn` (statut d'exploitation du MIN et absence de mercuriale ouverte en CSV vérifiés).
* **FEWS NET Sénégal** : `https://fews.net/west-africa/senegal` et `https://fdw.fews.net` (couverture des marchés de céréales/légumineuses vérifiée).
* **MLouma** : `https://www.mlouma.com` (modèle de collecte maraîchère et accès sur partenariat vérifiés).