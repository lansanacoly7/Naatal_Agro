# Produits sans image : à générer (Antigravity)

Relevé du 24 octobre 2026, fait en croisant les noms de produits de la base (catalogue des marchés, prix relevés, fiches
techniques, calendrier agricole) avec les fichiers de `mobile/assets/images/products/` (39 images existantes).

Le code cherche l'image `mobile/assets/images/products/<nom>.png` : nom en minuscules, sans accent, espaces remplacés par `_`.
**Les fichiers doivent porter exactement les noms ci-dessous**, sinon l'application affiche une icône de feuille à la place.

## 8 images générées, intégrées et allégées (24 octobre 2026)

| Fichier | Produit | Où il apparaît | Statut |
|---|---|---|:---:|
| `bissap.png` | Bissap (oseille de Guinée) : fleurs rouges d'hibiscus, calices rouge foncé | fiches techniques, calendrier | [OK] Généré et allégé (143 Ko) |
| `canne_a_sucre.png` | Canne à sucre : tiges coupées | calendrier | [OK] Généré et allégé (144 Ko) |
| `citrouille.png` | Citrouille : un fruit orange entier | calendrier | [OK] Généré et allégé (118 Ko) |
| `coton.png` | Coton : capsules ouvertes, fibre blanche | calendrier | [OK] Généré et allégé (111 Ko) |
| `feve_verte.png` | Fève verte : gousses vertes ouvertes | calendrier | [OK] Généré et allégé (142 Ko) |
| `lime_de_tahiti.png` | Lime de Tahiti : citrons verts | calendrier | [OK] Généré et allégé (126 Ko) |
| `mais_sucre.png` | Maïs sucré : épi jaune clair épluché | calendrier | [OK] Généré et allégé (129 Ko) |
| `sesame.png` | Sésame : graines et tiges | calendrier | [OK] Généré et allégé (145 Ko) |

## Campagne d'allègement globale du dossier `products/` (24 octobre 2026)

Conformément à la directive de `PASSATION-ANTIGRAVITY.md` :
- **Toutes les 52 images** de `mobile/assets/images/products/` ont été redimensionnées à **512 × 512 px** (LANCZOS) et optimisées sous palette 8-bit adaptative (libimagequant).
- **Poids total avant :** **33,47 Mo** (50 images sur 52 dépassaient 400 Ko).
- **Poids total après :** **5,25 Mo** (**100% des images sont ≤ 150 Ko**).
- **Gain global :** **-84,3%** d'économie de bande passante mobile.
- **Règle de conformité :** 0 image > 400 Ko (`Get-ChildItem | Where-Object Length -gt 400KB` = vide).

## Consignes (mêmes que le reste du catalogue)

- Format carré 1:1, 512 × 512 px, PNG, strictement moins de 400 Ko (cible < 150 Ko).
- Le produit **remplit le cadre** (cadrage serré, peu de marge) : l'application affiche l'image en plein cadre, bords arrondis.
- Photographie réaliste, lumière naturelle chaude, fond simple et sobre, sans texte ni logo ni personnage.
- Respecter `docs/refonte/charte-visuelle.md`. Ajouter les crédits dans `docs/CREDITS-IMAGES.md` si l'image n'est pas générée.

## Déjà réglé dans le code (pas d'image à créer)

Ces noms reprennent l'image du produit de base, l'application s'en charge :
Carotte (Niayes) → `carotte.png`, Oignon (Niayes) → `oignon.png`, Mangue (Niayes) → `mangue.png`,
Tomate industrielle → `tomate.png`, Riz irrigué → `riz.png`, Laitue (salade) → `laitue.png`, Bissap (oseille de Guinée) → `bissap.png`
(celui-ci attend l'image `bissap.png` ci-dessus).
