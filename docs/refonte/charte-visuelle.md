# Charte Visuelle & Système de Design — Refonte « Images d'Abord »

## 1. Vision et Contexte

**Naatal Agro** est le copilote intelligent des agriculteurs du Sénégal (zone des Niayes, Diamniadio, bassin arachidier, vallée du fleuve).
Beaucoup d'utilisateurs ruraux lisent peu ou pas le français. L'application doit donc **se comprendre immédiatement sans avoir besoin de lire**.
Toutes les fonctionnalités techniques existantes sont conservées ; la refonte introduit une ergonomie visuelle universelle et accessible.

---

## 2. Les 7 Principes Fondamentaux de Design

1. **Image avant texte**
   - Chaque fonction (Vendre, Récolter, Stock, Dépenses, Marchés, Météo, Cultures, Aide IA) est identifiable instantanément par une photo ou illustration claire et concrète.
   - Le texte est réduit à un **libellé court (1 à 3 mots)** placé sous ou sur l'image, jamais de phrase longue descriptive.

2. **Une action par écran (Hiérarchie stricte)**
   - Un écran met en avant en très grand l'action la plus fréquente.
   - Les actions secondaires sont plus petites ou regroupées dans un menu « Plus ».

3. **Grandes zones tactiles (≥ 56 px)**
   - Hauteur minimale de toucher fixée à **56 px** (`Hit.primary`), seuil minimum absolu à **48 px** (`Hit.min`).
   - Jamais de liens textuels minuscules : l'interface doit rester utilisable en plein soleil, avec des mains abîmées ou mouillées, ou en portant des gants de travail.

4. **Peu de saisie, interactions directes**
   - Préremplissage automatique maximal (dates du jour, région du profil, produit sélectionné, prix du marché local).
   - Privilégier les choix visuels par photos, les sélecteurs incrémentaux « + / − » et le clavier numérique dédié plutôt que le clavier textuel.

5. **Retour d'action visible et immédiat**
   - Après chaque enregistrement ou action : une grande coche animée, un changement de couleur clair, une vibration haptique.
   - Jamais un simple message texte discret.

6. **Zéro jargon technique**
   - Bannir les termes administratifs ou cryptiques (« ISRA », « CC BY », « indicatif », « code JTI ») non accompagnés d'une explication graphique ou visuelle évidente.

7. **Honnêteté des données et zéro fiction**
   - Aucune donnée ou statistique fictive.
   - Un écran ou bloc vide affiche une photo/illustration bienveillante et **un seul bouton d'action explicite** pour commencer.

---

## 3. Règle des 20 % de Vert et Palette par Domaine

L'application doit **respirer**. L'alternance systématique de blocs vert forêt et blancs est bannie.
- **Le vert foncé n'occupe qu'environ 20 % de la surface perçue** : réservé au logo de marque, aux boutons d'action principale, et à l'indicateur d'onglet actif de la barre de navigation.
- **Fond général chaud** : Crème sahélien `#FBF7F0` (au lieu du gris-vert froid). En mode sombre : `#0A0F0C`.
- **Cartes** : Blanches (`#FFFFFF`), avec icône, pastille ou bandeau arborant la couleur spécifique du domaine.

### Palette Sémantique des Domaines

| Domaine | Couleur | Code Hex | Jeton Dart | Usage |
|---|---|---|---|---|
| **Marque & Actions** | Vert Forêt | `#1B5E20` | `c.accent` / `AppColors.primary` | Boutons CTA principaux, logo, onglet actif |
| **Fond Général (Clair)** | Crème Chaud | `#FBF7F0` | `c.bg` / `AppColors.background` | Arrière-plan de tous les écrans |
| **Fond Général (Sombre)** | Noir Végétal | `#0A0F0C` | `c.bg` | Arrière-plan mode sombre |
| **Cultures** | Vert Feuillage | `#1B5E20` | `c.domainCultures` | Parcelles, cycles culturaux, calendrier |
| **Stock & Récolte** | Ocre Doré | `#D97706` | `c.domainStock` / `AppColors.accentGold` | Sacs, hangars, quantités entreposées |
| **Marchés & Prix** | Terre Cuite | `#A8401F` | `c.domainMarches` / `c.clay` | Cours des denrées, étals, loumas |
| **Météo** | Bleu Ciel | `#0284C7` | `c.domainMeteo` / `AppColors.accentSky` | Température, pluie, humidité, ciel |
| **Finances & Dépenses** | Bleu Ardoise | `#3A5670` | `c.domainFinances` / `c.slate` | Dépenses, intrants, recettes de vente |
| **Alertes & Prévention** | Orange Alerte | `#FF9500` | `c.domainAlerts` / `AppColors.warning` | Signalements sanitaires, chenilles, chaleur |
| **Erreur & Blocage** | Rouge Doux | `#FF3B30` | `AppColors.error` | Échecs de connexion, validation |
| **Naatal IA** | Violet Indigo | `#7C3AED` | `c.domainIa` | Assistant vocal, conseils personnalisés |

> **Règle stricte :** Toutes les couleurs sont référencées via les jetons (`context.c.<token>` ou `AppColors.<token>`), jamais codées en dur dans les widgets.

---

## 4. Tailles Minimales et Ergonomie

- **Hauteur des boutons d'action :** Minimum 56 px (`Hit.primary = 56`).
- **Tuiles photos d'action :** Hauteur 110 px à 160 px avec ratio 4:3, touch target intégrale.
- **Rayons de courbure :** 
  - Cartes et tuiles : `Radii.l` (20 px) ou `Radii.xl` (24 px).
  - Boutons pill : `Radii.pill` (99 px).
  - Feuilles inférieures (sheets) : `Radii.sheet` (30 px).
- **Typographie :**
  - Famille unique embarquée : `Onest` (police variable `assets/fonts/Onest.ttf`).
  - Chiffres toujours alignés avec `FontFeature.tabularFigures()`.
  - Libellés d'action : `T.body(weight: 700)` ou `T.caption(weight: 700)`.

---

## 5. Règles Spécifiques aux Images

1. **Format et poids :**
   - Format standard : Ratio **4:3** (1024 × 768 px).
   - Format de fichier : **JPG** optimisé (qualité 80-85) ou **PNG**.
   - Poids strictement inférieur à **400 Ko** par image pour garantir un affichage fluide même sur smartphone d'entrée de gamme en zone rurale.
2. **Contenu visuel :**
   - Scènes réelles situées au Sénégal (Niayes, Diamniadio, Thiès, bassin arachidier).
   - Personnes d'origine ouest-africaine, attitudes dignes, chaleureuses et naturelles.
   - Lumière naturelle et chaude (soleil sahélien, matinée ou fin d'après-midi).
   - Aucun texte incrusté, aucun logo, aucun chiffre dans l'image brute.
3. **Traitement d'affichage :**
   - Dégradé sombre subtil en bas de l'image (`LinearGradient` noir transparent vers `0.70` d'opacité) pour assurer un contraste parfait du libellé blanc.
   - Pastille colorée ou icône de domaine dans le coin supérieur pour ancrer visuellement le domaine fonctionnel.

---

## 6. Bibliothèque d'Images Fondatrices (`mobile/assets/images/ui/`)

| Fichier | Domaine | Scène représentée | Poids |
|---|---|---|---|
| `ui_vendre.jpg` | Vente | Étal maraîcher sénégalais avec commerçante souriante et beaux légumes frais | ~200 Ko |
| `ui_recolter.jpg` | Récolte | Agricultrice sénégalaise dans un champ maraîcher avec panier de récolte | ~211 Ko |
| `ui_stock.jpg` | Stock | Hangar de stockage aéré et propre avec sacs de jute bien empilés | ~196 Ko |
| `ui_depenses.jpg` | Dépenses | Agriculteur sous un arbre vérifiant son carnet de dépenses et semences | ~171 Ko |
| `ui_marches.jpg` | Marchés | Marché rural hebdomadaire (louma) sénégalais animé aux étals colorés | ~237 Ko |
| `ui_ia.jpg` | Aide IA | Conseiller agricole et fermier échangeant autour d'un smartphone au champ | ~152 Ko |
| `ui_cultures.jpg` | Cultures | Parcelles maraîchères verdoyantes des Niayes avec canaux d'irrigation | ~231 Ko |
| `ui_meteo.jpg` | Météo | Ciel doré et nuages doux au-dessus de la plaine sahélienne bordée de baobabs | ~144 Ko |
