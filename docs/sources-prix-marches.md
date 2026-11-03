# Sources des prix de marché

## Prix officiels (importés)

- **Jeu de données :** « Senegal – Food Prices », Programme alimentaire mondial (PAM / WFP), publié sur HDX
  (https://data.humdata.org/dataset/wfp-food-prices-for-senegal). Relevés de prix de détail faits par l'ANSD / le CSA, repris par la FAO.
  Licence **CC BY-IGO** : la source doit être citée. Données vérifiées le 31 octobre 2026 : relevés de 2000 à août 2026.
- **Commande :** `python manage.py import_wfp_prices` (télécharge le fichier, ou `--file chemin.csv`). Rejouable : à relancer après chaque
  mise à jour mensuelle du jeu de données. Importe 24 mois par défaut (`--months`).
- **Ce qui est importé :** prix de détail réels (`actual`), en francs CFA par kilo, pour 18 produits : mil, maïs (local), sorgho, niébé,
  arachide décortiquée, riz (local), oignon sec, pomme de terre, tomate, chou, carotte, manioc, patate douce, banane, mangue, pastèque,
  orange, fonio. Les variantes importées et le bétail ne sont pas repris.
- **Ce que ça remplace :** pour chaque couple (marché, produit) couvert, les prix générés sont supprimés. Le reste est inchangé.
- **Dans l'application :** chaque produit issu de ces relevés porte la mention « Relevé officiel PAM / ANSD » et la date du relevé.
  Les relevés sont mensuels : la courbe couvre un an et aucune prévision n'est calculée (trop peu de points).

## Prix générés (démonstration)

Les autres couples (marché, produit) gardent les prix produits par `generate_market_data` (départ + variations aléatoires). Ils ne sont pas
des relevés. À remplacer petit à petit par des relevés réels (ARM, CSA/SIM, producteurs, MIN de Diamniadio).
