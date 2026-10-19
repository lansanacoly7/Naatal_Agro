# PASSATION : Antigravity reprend seul la refonte de Naatal Agro

> Ce fichier est écrit pour que tu travailles **sans Claude et sans OpenCode**. Lis-le en entier, puis exécute le plan
> de la section 7 dans l'ordre. Réponds toujours en **français**, de façon **courte** : l'utilisateur est pressé et
> compte ses tokens. Tu es désormais à la fois celui qui conçoit, qui code et qui vérifie.

---

## 1. Le projet en une minute

- **Naatal Agro** : application mobile (Flutter) + API (Django) pour les agriculteurs du Sénégal (zone Diamniadio, Niayes,
  bassin arachidier). C'est un projet de fin de formation (ISEP). Langue de l'interface : **français**.
- Dépôt : `Projet_de_fin_de_formation_Naatal_Agro/`
  - `backend/` : Django 5 + DRF + SimpleJWT (apps : users, agriculture, markets, finances, inventory, weather,
    notifications, ai_assistant, analytics, privacy).
  - `mobile/` : Flutter 3.41, Riverpod 2.6 (StateNotifier/FutureProvider), go_router 14, dio, fl_chart, flutter_map.
  - `web/` : **INTERDIT, n'y touche jamais** (site React de l'équipe). Ne le modifie pas, ne le compile pas.
  - `docs/` : documentation (06 API, 07 mobile, refonte/, CREDITS-IMAGES.md…).
- Branche de travail : `refonte/design-apple` (commits **locaux**, jamais poussés). Le tag `design-avant-refonte`
  (et la branche `sauvegarde/design-avant-refonte`) conserve l'ancien design : **ne les modifie pas**.
  Pour consulter un ancien écran : `git show design-avant-refonte:mobile/lib/...`.
- **Ne fais ni `git commit` ni `git push` sauf demande explicite de l'utilisateur.**

## 2. Règles absolues (l'utilisateur y tient)

1. **Zéro donnée factice.** Toute valeur affichée vient de l'API/de la base ; sinon on affiche un état vide honnête.
   Pas de prix, de cycle, de météo, de pourcentage ni de « conseil » inventé. Une estimation est toujours étiquetée
   « indicatif » (et jamais présentée comme une garantie). Seule exception : le **compte démo** (section 5), dont les
   données fictives sont créées par `python manage.py setup_demo`.
2. **Le vert principal est `#1B5E20`**, partout (`AppColors.primary` et `NaatalColors.light.accent` doivent rester
   identiques). Aucun autre vert « principal ». Voir la palette (section 4) : l'appli doit **respirer**, le vert ne
   couvre qu'environ 20 % de l'écran.
3. **Images d'abord, texte ensuite** : beaucoup d'agriculteurs lisent peu. Les fonctions se reconnaissent à une photo
   ou une illustration ; le texte est un libellé court (1 à 3 mots). Toutes les fonctionnalités restent.
4. **Pas de mode sombre** (désactivé volontairement : `themeMode: ThemeMode.light`).
5. **Respect des licences.** Toute image non générée (téléchargée) doit être listée dans `docs/CREDITS-IMAGES.md`
   (fichier, auteur, licence, lien). Préfère toujours générer l'image.
6. **Secrets** : les clés `GROQ_API_KEY` et `GEMINI_API_KEY` sont dans le `.env` de la racine (ignoré par git).
   Ne les affiche jamais, ne les copie nulle part.
7. **Un seul projet** : travaille uniquement dans ce dépôt. N'expose jamais un autre projet de l'utilisateur
   (voir la section 6, tunnel).
8. **Une page à la fois**, puis vérification complète avant la suivante.

## 3. État de l'application (ce qui est fait)

### Backend (tests : 230 passent, `cd backend && venv\Scripts\python manage.py test`)
- Auth par téléphone + JWT ; OTP (`/api/users/auth/otp/send|verify/`, reset mot de passe). Le code OTP n'est renvoyé
  dans la réponse que si `OTP_DEMO_MODE=True` (par défaut = `DEBUG`) ; tentatives limitées (`OTP_MAX_ATTEMPTS=5`).
- Routes ajoutées : `GET /api/markets/prices/latest/?product=` et `GET /api/markets/prices/history/?product=&market=&days=`.
- `/api/dashboard/` : `markets` = prix des **cultures de l'utilisateur** (avec `min_price`, `max_price`,
  `markets_count`, `change_percent`), `weather` de **sa** région uniquement (+`date`).
- `.env` racine chargé par Django (`backend/core/settings/base.py`).
- API documentée dans `docs/06-Backend-API.md`.

### Mobile : design system (`mobile/lib/ui/`, import unique `ui/ui.dart`)
- `tokens.dart` (`NaatalColors` via `context.c`, `Space`, `Radii`, `Motion`, `Hit`), `typography.dart`
  (police **Onest** embarquée ; styles `T.largeTitle/title/body/caption/number/figure`), `theme.dart`
  (`NaatalTheme.light`, `AuthStyle`), composants (`cards`, `sheets`, `states`, `pill_button`, `keypad`,
  `success_reveal`, `motion_widgets` dont `AuroraBackground`, `Reveal`, `AnimatedNumber`…).
- Les anciens écrans utilisent encore `AppColors` (`mobile/lib/core/theme/app_theme.dart`).
- `main.dart` applique un `textScaler` global de 0,9 (texte plus petit) : respecte-le.

### Mobile : écrans et routes (`mobile/lib/core/router/app_router.dart`)
Navigation : `MainShell` (barre fixe, 5 onglets : Accueil `/`, Cultures `/agriculture`, Marchés `/markets`,
Naatal IA `/ai`, Profil `/profile`). Écrans hors onglets en dessous.

| Zone | Écran actuel | Fichier |
|---|---|---|
| Présentation, connexion, inscription, bienvenue | **anciens écrans re-stylés** (structure d'origine voulue par l'utilisateur) | `features/auth/presentation/screens/` |
| Accueil `/` | ancienne structure restaurée + corrections d'honnêteté | `features/dashboard/presentation/screens/dashboard_screen.dart` |
| Carrousel de conseils (accueil) | basé sur l'activité réelle, 6 s, images `assets/images/conseils/*.jpg` | `features/dashboard/presentation/widgets/advice_carousel.dart` |
| Prix du marché (accueil) | ancienne section restaurée, courbe lisse, bouton « Analyser » en bas | `.../widgets/market_prices_section.dart` |
| Mon Dashboard (résumé accueil + page `/mon_dashboard`) | refait (Antigravity) | `.../widgets/my_dashboard_section.dart`, `my_dashboard_logic.dart`, `screens/mon_dashboard_screen.dart` |
| Cultures `/agriculture` | **nouvelle** : onglets « Mon exploitation » / « Découvrir » | `features/agriculture/presentation/screens/cultures_screen.dart` |
| Fiche catalogue `/agriculture/culture` (extra `Product`) | nouvelle fiche unique (prix, cycle, fiche technique) | `culture_fiche_screen.dart` |
| Ajout d'une culture `/agriculture/add` | refait : liste déroulante + recherche, cycle ISRA en valeur, dates auto | `add_crop_screen.dart` |
| Fiche de ma culture `/crop_detail` (extra `Crop`) et `/agriculture/:id` | **ancien écran** | `crop_detail_screen.dart` |
| Fiches techniques `/agriculture/guides` | nouveau | `screens/guides/guides_screens.dart` (`GuidesListScreen`, `GuideDetailScreen`, `GuideSections`) |
| Marchés `/markets` | **nouveau** (carte OSM, géolocalisation à la demande, classement, courbe 30 j) : l'utilisateur l'aime, **ne le casse pas** | `screens/markets/` |
| Vente `/sell`, Stock `/stock`, Finances `/finances` | nouveaux (clavier numérique, etc.) | `screens/sell/`, `screens/stock/`, `screens/finances/` |
| Naatal IA `/ai` | nouveau | `screens/assistant/assistant_screen.dart` |
| Profil `/profile`, Notifications `/notifications` | nouveaux (Profil a « Crédits photos ») | `screens/profile/`, `screens/notifications/` |
| Météo `/weather` | ancien design (hérité de Pathé) | `features/weather/` |

### PWA (le lien de test sur téléphone)
`mobile/web/` contient le manifeste, les icônes, `naatal_sw.js` (cache hors ligne ; **jamais l'API**), `offline.html`,
la bannière d'installation (dans `index.html`). Ne touche pas au dossier `web/` de la racine : c'est `mobile/web/` qui
est concerné.

## 4. Charte visuelle à appliquer (refonte « images d'abord »)

**Principes** : (1) image avant texte ; (2) une action principale par écran ; (3) zones à toucher ≥ 56 px ;
(4) peu de saisie : préremplir (dates, région, produit), choix par photo, boutons − / +, clavier numérique de
l'appli plutôt que clavier texte ; (5) retour visible après chaque action (grande coche animée) ; (6) pas de jargon ;
(7) écran vide = une image + un seul bouton.

**Palette** (à définir uniquement dans les jetons `app_theme.dart` et `ui/tokens.dart`, jamais en dur dans un écran) :
- Marque : `#1B5E20` (logo, bouton principal, élément actif). Pas d'autre vert foncé.
- Fond général : crème chaud, par exemple `#FBF7F0` (remplace le gris-vert actuel).
- Une couleur par domaine, sur les icônes, pastilles et photos teintées : **Cultures** = vert de marque ;
  **Stock** = ocre `AppColors.accentGold` (`#D97706`) ; **Marchés/prix** = terre cuite (`NaatalColors.clay`) ;
  **Météo** = bleu ciel `AppColors.accentSky` (`#0284C7`) ; **Finances** = bleu ardoise (`NaatalColors.slate`) ;
  **Alertes** = orange (rouge `AppColors.error` pour une erreur) ; **Naatal IA** = indigo/violet doux.
- Cartes blanches, avec la couleur du domaine sur l'icône ou le bandeau. Interdit : alternance de blocs verts et blancs.

**Images** : dossiers `mobile/assets/images/ui/` (nouvelles), `.../conseils/` (11 existantes), `.../products/`
(35 produits). Format 4:3 (ou 1:1 pour les produits), moins de 400 Ko, sans texte ni logo, lumière chaude, Sénégal,
personnes ouest-africaines. Génère-les ; si le quota est épuisé, note-le et réessaie plus tard (ne remplace pas par
des photos téléchargées sans les créditer). Les prompts existants sont dans `docs/refonte/prompts-images-conseils.md`.

## 5. Environnement de travail et vérification

### Lancer et vérifier
- Analyse : `cd mobile && flutter analyze lib` → doit afficher « No issues found! ».
- Tests : `cd mobile && flutter test` (95 tests aujourd'hui). `SHOTS_DIR="$PWD/build/shots" flutter test`
  écrit des captures PNG dans `mobile/build/shots/` (voir `test/screens_visual_test.dart` et
  `test/support/visual_harness.dart`). Les images/assets ne s'affichent pas dans ces captures de test : c'est normal.
- Backend : `cd backend && venv\Scripts\python manage.py test` ; démarrer : `set DJANGO_SETTINGS_MODULE=core.settings.local`
  puis `venv\Scripts\python manage.py runserver 127.0.0.1:8000`.
- **Compte démo (données fictives, dev uniquement)** : `cd backend && python manage.py setup_demo` ;
  téléphone `+221770000000` (à la saisie : `770000000`), mot de passe `DemoSenegal2026#`. La commande refuse de
  s'exécuter hors `DEBUG`/`OTP_DEMO_MODE`.

### Pièges déjà rencontrés (gagne du temps)
- **Git Bash convertit les chemins** (ex. `/api` devient un chemin Windows). Compile avec
  `MSYS_NO_PATHCONV=1 flutter build web --release --dart-define=API_BASE_URL=/api --output=build/web_tunnel`.
- `intl` n'a pas ses données françaises sur le web : n'utilise pas `DateFormat(..., 'fr_FR')` ; formate les dates à la main.
- Un `heredoc` bash avec une apostrophe casse : écris les scripts dans des fichiers.
- Le service worker met l'interface en cache : après un nouveau build, recharge la page **deux fois**.
- L'application installée sur l'écran d'accueil garde l'adresse du tunnel du moment : si l'adresse change, il faut la
  supprimer et la réinstaller.

### Voir le résultat sur le téléphone (lien temporaire)
1. Compiler (commande ci-dessus), puis servir `mobile/build/web_tunnel` avec un petit serveur qui **relaie `/api` et
   `/media` vers `127.0.0.1:8000`** (annexe A). **Utilise le port 3100** : le port 3000 est occupé par un autre
   projet de l'utilisateur (KerIA) qu'il ne faut jamais exposer.
2. Ouvrir un tunnel `cloudflared tunnel --url http://127.0.0.1:3100 --no-autoupdate` (binaire dans le dossier temporaire
   de la session ; à retélécharger depuis les versions officielles de Cloudflare si besoin). L'adresse
   `https://….trycloudflare.com` change à chaque redémarrage.
3. **Avant de donner l'adresse**, vérifie : la page affiche bien « Naatal Agro », et une connexion avec le compte démo
   répond 200 via le tunnel. Coupe le tunnel quand l'utilisateur a fini (c'est public).
4. Une page de diagnostic `diag.html` peut être déposée dans `build/web_tunnel/` : elle teste depuis le téléphone
   la joignabilité de l'API.

## 6. Problèmes connus à corriger (liste de reprise)

1. **Mon Dashboard** : « Détails > » apparaît deux fois ; la mini-carte « Opportunités » n'est pas visible sans défiler ;
   vérifier le bas de `/mon_dashboard` (Investir, Prévision, Conseils).
2. **Accueil, « Produits en vedette »** : cartes avec « Rentabilité : » **vide** et une icône de chrono sans texte
   (champs non alimentés) → vraie donnée ou suppression.
3. **Fiche de ma culture** (`crop_detail_screen.dart`) : pastilles de tâches cochables mais **non enregistrées**
   → soit enregistrer via `addActivity` (API existante), soit supprimer. Dates en français sans `intl`.
4. **Catalogue** : beaucoup de prix sont des valeurs de référence, pas des relevés → l'indiquer (« prix de référence »).
5. **Images** : `piment.png` et `manioc.png` sont des photos de terrain recadrées (pas le style studio des autres) →
   à regénérer dès que le générateur d'images est disponible ; 9 photos produits viennent de Wikimedia (crédits dans
   `docs/CREDITS-IMAGES.md`).
6. **Anciens écrans à retirer ou refaire** : `/product_detail`, `/price-alerts` (alertes locales non fiables),
   `/settings-*`, anciens écrans `features/profile`, `features/markets` (comparaison/détail), `weather_screen`.
7. **Dictionnaire wolof** (`mobile/lib/core/localization/`) : traductions non vérifiées par un locuteur, non utilisées
   dans l'interface ; ne les active pas sans validation.
8. **Backend (audit)** : références canoniques Produit/Région, historique des mouvements de stock, notifications push
   (FCM), vraie source des prix, vérification Docker/TLS, retirer le cycle par défaut de 90 jours côté
   `CropSerializer`, vrai SMS OTP, adresse de support (à fournir par l'utilisateur).
9. **Hébergement** : le lien tunnel est temporaire. Une adresse fixe demande un hébergement (site sur Cloudflare Pages /
   Netlify, backend sur Render ou équivalent, base PostgreSQL externe) : à ne faire qu'avec l'accord de l'utilisateur
   et ses comptes. **`OTP_DEMO_MODE` doit rester éteint avec de vrais utilisateurs.**

## 7. Plan d'exécution (dans l'ordre ; une étape = vérifier avant de passer à la suivante)

### Étape A : fondations et accueil
- Crée `docs/refonte/charte-visuelle.md` (principes, palette avec valeurs, tailles, règles d'images).
- Ajoute dans `app_theme.dart` et `ui/tokens.dart` la palette par domaine et le fond crème ; fais en sorte que les
  écrans existants les prennent par défaut sans toucher au vert de marque.
- Crée dans `mobile/lib/ui/` : `PhotoTile` (grande carte photo plein cadre + légende courte + dégradé bas),
  `BigActionButton` (très grand bouton photo/icône + libellé court), et enrichis `EmptyState` (image + un bouton).
- Accueil : « Actions rapides » = 4 à 6 grandes tuiles photo (Vendre, Récolter, Stock, Dépenses, Marchés, Aide IA) ;
  réduis le texte ; photos pour « Aujourd'hui », « Conseils », « Produits en vedette ». Corrige les points 1 et 2 de la
  section 6. Garde toutes les fonctions et les écrans qu'elles ouvrent.
- Images à produire dans `mobile/assets/images/ui/` : `ui_vendre`, `ui_recolter`, `ui_stock`, `ui_depenses`,
  `ui_marches`, `ui_ia`, `ui_cultures`, `ui_meteo`.

### Étape B : Cultures, « images d'abord »
Fichiers : `cultures_screen.dart`, `culture_fiche_screen.dart`, `add_crop_screen.dart`, `crop_detail_screen.dart`.
- **Mon exploitation** : chaque culture = grande carte photo avec un seul chiffre bien visible (« Récolte dans 48 j » ou
  grande coche « Récoltée »), barre de progression plus épaisse, filtres en boutons à icônes.
- **Découvrir** : grille de photos (2 colonnes), nom en un mot ; la recherche texte reste mais passe au second plan.
- **Ajout** : choix de la culture sur une **grille de photos** (les plus courantes d'abord) avec recherche au-dessus ;
  une fois choisie : photo en grand, cycle officiel en valeur, dates et région déjà remplies ; surface avec boutons
  − / + ou clavier numérique ; un seul grand bouton « Ajouter ».
- **Fiche de ma culture** : 4 grands boutons photo (Arroser, Engrais, Traiter, Récolter) qui **enregistrent**
  l'activité (date du jour) avec grande coche animée ; coût facultatif au clavier numérique ; supprime les pastilles
  non enregistrées ; affiche les récoltes déjà faites.
- Images : `ui_arroser`, `ui_engrais`, `ui_traiter`, `ui_recolter_geste`, `ui_premiere_culture`.

### Étape C : les autres pages, une par une, dans cet ordre
Marchés (affinage seulement : l'utilisateur aime cette page ; applique la palette et le côté « images d'abord » sans la
casser), Stock et Vente, Finances, Naatal IA (photo et boutons-suggestions), Profil, Connexion et Inscription
(garde la structure d'origine voulue : mêmes champs et boutons ; applique seulement le style).
Pour chaque page : (1) garder toutes les fonctions ; (2) images d'abord ; (3) peu de saisie ; (4) palette ;
(5) zéro donnée factice ; (6) vérifier (analyse, tests, capture réelle via le lien).

### Étape D : nettoyage et qualité
Points 3 à 8 de la section 6 ; mettre à jour `docs/06`, `docs/07` (palette, nouveaux composants, routes) et le README ;
relancer toute la suite de tests (backend + mobile).

## 8. Définition de « terminé » pour une page

- `flutter analyze lib` propre et `flutter test` vert.
- Aucune couleur en dur dans les écrans ; vert de marque `#1B5E20` unique ; le vert n'occupe qu'environ 20 %.
- Toutes les fonctions d'origine existent encore ; chaque action enregistre vraiment (ou n'existe pas).
- Une image par fonction principale ; textes courts ; zones ≥ 56 px ; peu de saisie.
- Aucune donnée inventée ; états vides honnêtes ; images créditées si non générées.
- Capture réelle vérifiée sur le lien (connexion avec le compte démo).
- Rapport à l'utilisateur : court, en français, avec la liste des fichiers modifiés et ce qui reste.

## Annexe A : petit serveur pour le lien (à enregistrer hors dépôt, par exemple `serve.js`)

```js
// node serve.js <dossier build/web_tunnel> 3100 : sert le site et relaie /api et /media vers Django.
const http = require('http'), fs = require('fs'), path = require('path');
const root = path.resolve(process.argv[2]), port = Number(process.argv[3] || 3100);
const types = { '.html':'text/html','.js':'text/javascript','.json':'application/json','.css':'text/css','.png':'image/png','.jpg':'image/jpeg','.svg':'image/svg+xml','.wasm':'application/wasm','.otf':'font/otf','.ttf':'font/ttf' };
http.createServer((req, res) => {
  if (req.url.startsWith('/api') || req.url.startsWith('/media')) {
    const p = http.request({ host:'127.0.0.1', port:8000, path:req.url, method:req.method, headers:{...req.headers, host:'127.0.0.1:8000'} },
      r => { res.writeHead(r.statusCode, r.headers); r.pipe(res); });
    p.on('error', () => { res.writeHead(502); res.end('Backend indisponible'); });
    req.pipe(p); return;
  }
  let f = path.join(root, decodeURIComponent(req.url.split('?')[0]));
  if (!f.startsWith(root) || !fs.existsSync(f) || fs.statSync(f).isDirectory()) f = path.join(root, 'index.html');
  res.writeHead(200, { 'Content-Type': types[path.extname(f)] || 'application/octet-stream', 'Cache-Control': 'no-cache' });
  fs.createReadStream(f).pipe(res);
}).listen(port, '127.0.0.1');
```
