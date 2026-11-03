# Recherche de sources de prix de marché au Sénégal — Naatal Agro

**Date de consultation : 31 octobre 2026**  
**Objectif :** identifier des sources réelles, récentes et exploitables pour afficher les prix des produits agricoles dans Naatal Agro, en priorité pour Dakar, les marchés non couverts par le jeu WFP/HDX et les 17 produits horticoles manquants.

## Critère de fraîcheur appliqué

Seules les sources dont le dernier relevé date de moins de trois mois, soit après fin juillet 2026, ont été retenues comme sources actives. Les sources plus anciennes sont listées séparément dans la rubrique « Sources existantes mais périmées ».

## Tableau récapitulatif

| Source | Date du dernier relevé vérifié | Marchés | Produits | Fréquence | Accès | Licence / usage | Priorité |
|---|---:|---|---|---|---|---|---|
| **Banque mondiale — Senegal Monthly Food Price Estimates by Product and Market** | **1er octobre 2026** ; version du jeu de données : **5 octobre 2026** | **67 marchés au Sénégal**, dont Dakar-Tilène apparaît dans les publications associées | Prix alimentaires par produit et marché ; couverture 2007–2026 | Mensuelle | Jeu de données public téléchargeable via le catalogue Banque mondiale / Microdata | Classé **Public** ; vérifier la licence exacte dans le fichier avant redistribution | **1 — très haute** |
| **FAO GIEWS — FPMA Tool / Regional Roundups** | Bulletin régional publié le **13 octobre 2026** ; données analysées pour juillet–août 2026 | Marchés suivis au Sénégal, dont Dakar-Tilène dans les analyses régionales | Principalement riz local, maïs, mil ; pas les 17 produits horticoles demandés | Mensuelle | Pages web, bulletins PDF et données FPMA ; accès gratuit | Contenu FAO généralement réutilisable avec attribution ; vérifier la licence exacte du fichier téléchargé | **2 — haute pour céréales** |
| **FEWS NET — Price Watch / staple food price data** | **30 septembre 2026** pour le Price Watch de septembre ; données de prix présentées comme publiques et mises à jour | Dakar-Tilène et Matam figurent parmi les séries suivies | Denrées de base, surtout céréales ; pas les fruits, légumes et condiments demandés | Mensuelle | Bulletins web/PDF et données publiques sur la page Markets and Trade Data | Données publiques ; conditions exactes à contrôler dans le jeu de données téléchargé | **3 — utile en complément** |
| **ARM — Agence de Régulation des Marchés** | **Non trouvé** : aucune publication récente de relevés de prix datés n’a été vérifiée en ligne | Non trouvé publiquement | Non trouvé publiquement | Non trouvé | Site institutionnel et contact public ; pas de fichier/API vérifié | À demander directement | **4 — piste institutionnelle majeure** |
| **SOGIP / MIN de Diamniadio** | **Non trouvé** : aucun relevé de prix daté ou fichier téléchargeable récent n’a été vérifié | MIN Diamniadio | Non trouvé | Non trouvé | Page institutionnelle uniquement | À demander directement | **4 — piste pour produits maraîchers** |
| **Maggu — marketplace / prix de référence** | **Non trouvé** : la page affirme que ses prix proviennent du Bulletin mensuel ANSD, sans date de dernier relevé vérifiable | Marchés sénégalais, selon la plateforme | Produits agricoles, en FCFA/kg | Mensuelle, selon la plateforme | Page web | Non précisée | **Faible — source dérivée** |

## Les 3 meilleures pistes

### 1. Banque mondiale — estimations mensuelles par marché

C’est la piste la plus directement exploitable pour Naatal Agro. Le jeu de données couvre **67 marchés sénégalais** et indique une couverture allant jusqu’au **1er octobre 2026**, avec une version publiée le **5 octobre 2026**.

- **Lien direct :** https://datacatalog.worldbank.org/search/dataset/0065641/senegal-monthly-food-price-estimates-by-product-and-market  
- **Lien Microdata :** https://microdata.worldbank.org/index.php/catalog/6173  
- **Intérêt :** combler Dakar et élargir la couverture géographique au-delà des 52 marchés WFP.  
- **Nature des données :** estimations mensuelles par produit et marché, produites à partir d’enquêtes sous-nationales et de méthodes d’imputation. Il s’agit donc d’une source **dérivée**, à étiqueter clairement comme « estimation » dans l’application.  
- **Limite :** vérifier produit par produit si les 17 produits manquants sont réellement présents dans le fichier. La page ne les énumère pas.

**Produits manquants à vérifier :** ananas, citron, goyave, melon, papaye, ail, aubergine, betterave, concombre, courge, gombo, haricot vert, laitue, navet, piment, poivron, igname.

### 2. ARM — demander l’accès au SIM modernisé

L’ARM est l’institution la plus pertinente pour obtenir des relevés **primaires**. Son mandat comprend la constitution d’une base de données sur la production, la consommation, l’évolution des prix et les tendances de marché. En septembre 2026, elle travaillait avec Enabel à la modernisation de son SIM pour mieux suivre production, récoltes, stocks et prix.

- **Lien institutionnel :** https://www.arm.gouv.sn/index.php/larm/  
- **Contact publié sur le site :** téléphone **33 869 16 17** ; e-mail **agencederegulation@gmail.com**.  
- **Intérêt :** meilleure voie pour obtenir des prix de terrain récents, notamment pour Dakar, Pikine, Rufisque, Touba, Mbour, Ziguinchor et le MIN.  
- **Limite vérifiée :** aucune publication publique, fichier CSV/Excel ou API ARM avec une date de relevé récente n’a été trouvée. Cela doit faire l’objet d’une demande formelle.

### 3. SOGIP / MIN de Diamniadio — demander les cotations de gros

Le MIN de Diamniadio est opérationnel et présenté par la SOGIP comme un marché de 24 hectares avec 137 magasins. C’est une source potentielle très intéressante pour les prix de gros des fruits et légumes.

- **Lien direct :** https://sogip.sn/marche-dinteret-national/  
- **Intérêt :** le MIN est précisément le maillon manquant pour les produits périssables et maraîchers absents du jeu WFP.  
- **Limite :** aucune cotation publique datée, fichier ou API n’a été trouvée sur les pages consultées. La piste est donc institutionnelle et nécessite un contact direct.

## Modèle de courriel

**Objet : Demande d’accès aux relevés récents de prix des marchés agricoles**

Madame, Monsieur,

Je développe Naatal Agro, une application mobile destinée aux agriculteurs sénégalais, afin de faciliter l’accès aux prix des produits agricoles.

Nous utilisons actuellement les données publiques du PAM, mais leur couverture reste limitée pour Dakar, certains marchés urbains et plusieurs fruits et légumes.

Votre institution semble disposer de relevés ou d’informations récentes sur les prix, notamment via son système d’information sur les marchés.

Pourriez-vous nous indiquer si ces données peuvent être partagées à des fins non commerciales et éducatives ?

Nous recherchons particulièrement les relevés les plus récents pour Dakar, Pikine, Rufisque, Touba, Mbour, Ziguinchor et le MIN de Diamniadio.

Les produits prioritaires sont les fruits, légumes, aromates et condiments couramment vendus sur ces marchés.

Un fichier Excel, CSV, PDF ou tout format exploitable nous serait très utile, avec la date et le marché de chaque relevé.

Nous citerons systématiquement votre institution comme source et respecterons vos conditions d’utilisation.

Je reste disponible pour tout échange et vous remercie par avance de votre retour.

Cordialement,  
Goat Ussop  
Développeur de Naatal Agro

## Sources existantes mais périmées

- **ANSD — Bulletin mensuel des statistiques économiques et financières** : dernière publication vérifiée le **16 février 2026** ; couvre les prix agricoles, mais dépasse le seuil de trois mois.  
- **ANSD — Flash stats / IPCE** : dernière publication identifiée le **24 février 2026**, portant sur décembre 2025 ; indicateur macroéconomique, pas un relevé par marché.  
- **FAOSTAT Food Prices for Senegal via HDX** : jeu de données indiqué comme mis à jour le **6 avril 2026** ; agrégats nationaux plutôt que relevés frais par marché et produit.  
- **Maggu** : source dérivée du Bulletin ANSD, sans dernière date de relevé vérifiable ; non exploitable sous le critère de fraîcheur.

## Ce qui reste introuvable

- **ARM** : publication publique récente, fichier téléchargeable, API ou date exacte de dernier relevé — **non trouvé**.  
- **CSA / SIM** : page ou fichier public récent avec date exacte de dernier relevé — **non trouvé**.  
- **SOGIP / MIN** : cotation publique datée, CSV, Excel ou API — **non trouvé**.  
- **Direction du Commerce intérieur, DAPSA, ISRA** : publication récente et exploitable de prix par marché — **non trouvé**.  
- **RESIMAO / CILSS** : page ou jeu de données sénégalais récent avec date de dernier relevé vérifiable — **non trouvé**.  
- **Manobi** : preuve vérifiable d’un service de prix toujours actif en 2026, avec données publiques ou API — **non trouvé**.  
- **Open Data Sénégal** : jeu de données de prix agricoles par marché, à jour après juillet 2026 — **non trouvé** ; l’ANSD mentionne une plateforme Agridata, sans preuve de relevés de prix récents téléchargeables.  
- **Rapports 2026 d’Enda, IPAR, USAID, GIZ ou Banque mondiale contenant des relevés de prix par marché** : **non trouvé** sous forme de données réutilisables et à jour.

## Recommandation pratique

1. Intégrer d’abord le jeu de données de la **Banque mondiale** comme couche « estimation mensuelle ».  
2. Demander simultanément à l’**ARM** et à la **SOGIP/MIN** un accès aux relevés primaires.  
3. Distinguer dans l’interface :  
   - « Prix observé — source officielle » ;  
   - « Prix estimé — Banque mondiale ».  
4. Afficher systématiquement la date du relevé, le marché et l’organisme source afin de préserver la confiance des utilisateurs.

## Sources consultées

- Banque mondiale — Senegal Monthly Food Price Estimates by Product and Market : https://datacatalog.worldbank.org/search/dataset/0065641/senegal-monthly-food-price-estimates-by-product-and-market  
- Banque mondiale Microdata — Senegal Monthly Food Price Estimates : https://microdata.worldbank.org/index.php/catalog/6173  
- FAO GIEWS — FPMA Regional Roundups : https://www.fao.org/giews/food-prices/regional-roundups/en/  
- FAO GIEWS — FPMA Tool : https://www.fao.org/giews/food-prices/home/en/  
- FAO GIEWS — FPMA Bulletin : https://www.fao.org/giews/reports/fpma-bulletin/fr/  
- FEWS NET — Markets and Trade : https://fews.net/topics/markets-and-trade  
- FEWS NET — Markets and Trade Data : https://fews.net/data/markets-and-trade  
- FEWS NET — September 2026 Price Watch : https://fews.net/global/price-watch/september-2026  
- ARM — Agence de Régulation des Marchés : https://www.arm.gouv.sn/index.php/larm/  
- SOGIP — Marché d’Intérêt National : https://sogip.sn/marche-dinteret-national/  
- Maggu — Prix de référence : https://www.maggu.sn/marketplace/prix  
- ANSD — Bulletin mensuel des statistiques économiques et financières : https://www.ansd.sn/Indicateur/bulletin-mensuel-des-statistiques-economiques-et-financieres  
- ANSD — Flash stats : https://www.ansd.sn/flash-stats  
- ANSD — Bases de données : https://www.ansd.sn/bases-de-donnees  
