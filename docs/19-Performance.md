# Naatal Agro — Performance : mesures, corrections et garde-fous

| Informations | Valeur |
|--------------|---------|
| Projet | Naatal Agro |
| Document | Bloc « Performance » (backend et mobile) |
| Règle | Chaque affirmation s'appuie sur une mesure reproductible. Aucune note chiffrée. |

---

# 1. Méthode (backend)

Deux mesures, dans `backend/core/test_performance.py` :

1. **Passage à l'échelle des requêtes SQL** (`QueryCountScalingTests`, exécuté à chaque `manage.py test` et en CI). Chaque point
   d'accès est appelé avec 3 puis 30 éléments par type de donnée. Le nombre de requêtes doit rester le même (à une près). S'il
   grandit avec les données, c'est un problème dit « N+1 » : une requête de plus par élément renvoyé.
2. **Temps de réponse** (`ResponseTimeReport`, à la demande) : 300 cultures (avec 3 activités chacune), 300 ventes, dépenses,
   stocks, notifications, signalements et échanges IA ; temps médian de 5 appels.

Commande du rapport complet :

```bash
cd backend
PERF_REPORT=1 python manage.py test core.test_performance
```

**Limites à connaître.** Mesures faites sur le client de test Django, avec SQLite, sur un poste de développement : les valeurs
absolues ne se transposent pas telles quelles à un serveur de production. Les écarts d'un lancement à l'autre atteignent environ
30 % sur les petits temps. Le **nombre de requêtes**, lui, est exact et reproductible : c'est l'indicateur fiable. Les temps ne
servent qu'à comparer l'avant et l'après sur la même machine.

---

# 2. Résultats

## 2.1 Nombre de requêtes SQL (avec 300 éléments)

| Point d'accès | Avant | Après | Cause corrigée |
|---|---:|---:|---|
| `GET /api/agriculture/crops/` | 301 | **2** | Les activités imbriquées de chaque culture étaient chargées une par une |
| `GET /api/finances/sales/` | 301 | **1** | Le nom de la culture de chaque vente était chargé une par une |
| `GET /api/privacy/export/` | 310 | **10** | Même cause que les ventes |
| `GET /api/finances/summary/` | 3 | 3 | Le calcul des recettes passe en base (voir ci-dessous) |
| Autres points d'accès (activités, signalements, fiches, transactions, stock, notifications, marchés, prix, produits, météo, assistant, profil) | 1 | 1 | Déjà corrects |
| `GET /api/dashboard/` | 10 | 10 | Constant (ne grandit pas avec les données) |

## 2.2 Temps de réponse (médiane, millisecondes, 300 cultures)

| Point d'accès | Avant | Après |
|---|---:|---:|
| `GET /api/agriculture/crops/` (toute la liste) | 1 483 | ≈ 1 000 à 1 180 |
| `GET /api/agriculture/crops/?page_size=20` | non mesuré | **≈ 104** |
| `GET /api/finances/sales/` | 927 | **≈ 285 à 297** |
| `GET /api/privacy/export/` | 4 599 | ≈ 2 750 à 2 850 |
| `GET /api/agriculture/activities/?page_size=20` | non mesuré | ≈ 33 |

**Lecture honnête.** Corriger les requêtes a fortement amélioré les ventes (environ ×3) et l'export (environ ×1,6). La liste complète
des cultures reste lente (environ 1 s pour 300 cultures et 900 activités) : le temps restant est celui de la sérialisation de
beaucoup de données, qu'aucune requête ne peut réduire. **La réponse est la pagination**, déjà disponible côté serveur
(`?page_size=20`) : avec elle, la même liste répond en environ 100 ms. D'où la tâche mobile ci-dessous : toutes les listes doivent
l'utiliser.

## 2.3 Autres corrections

- **Résumé financier** : les recettes des ventes sont calculées par la base (une requête d'agrégation) au lieu de charger chaque
  vente en mémoire puis de les additionner. Le résultat est identique (tests existants inchangés) ; la mémoire utilisée ne dépend
  plus du nombre de ventes.
- **Index et ordre par défaut** (déjà faits) : index sur les champs filtrés, ordre déterministe pour une pagination stable.

---

# 3. Garde-fous en place

- `QueryCountScalingTests` échoue dès qu'un point d'accès devient N+1 : toute future régression est détectée en CI, avec le nom du
  point d'accès et les deux nombres de requêtes.
- Pagination à la demande disponible sur toutes les listes (`docs/06-Backend-API.md` §13.4).
- Limites de débit (connexion, assistant IA) : protection contre les abus coûteux.

---

# 4. Tâches du bloc Performance

## Backend (Claude) : fait

N+1 corrigés, mesure automatisée, résumé financier en base, document de mesures.

## Backend : prévu, volontairement non fait

| Idée | Pourquoi pas maintenant |
|---|---|
| Cache des données publiques (marchés, prix, produits, fiches) | Ces points d'accès répondent déjà en moins de 30 ms ; le gain ne justifie pas la complexité (invalidation) |
| Pagination obligatoire par défaut | Casserait les anciens clients ; à activer quand tout le mobile envoie `page_size` |
| Pool de connexions et réglages de production (`CONN_MAX_AGE`, nombre de processus) | À faire avec la bascule vers PostgreSQL |

## Mobile (Antigravity) : à faire, mesurable

Chaque tâche demande une mesure **avant** et **après**, collée dans le compte rendu.

| N° | Tâche | Mesure demandée |
|---|---|---|
| P1 | Toutes les listes demandent `?page_size=20` avec « charger plus » (cultures déjà faite : ajouter notifications, transactions, stock, prix, fiches) | Nombre de lignes reçues au premier chargement de chaque liste avec 100 éléments côté serveur |
| P2 | Démarrage à froid : mesurer le temps jusqu'au premier écran utilisable, retirer tout travail bloquant dans `main()` et au premier écran | Temps de démarrage en mode profil sur émulateur, avant et après |
| P3 | Requêtes au démarrage : lister les appels réseau d'un démarrage à froid et supprimer les doublons (une donnée demandée deux fois) | Nombre d'appels API du démarrage à froid à l'écran d'accueil, avant et après |
| P4 | Reconstructions inutiles : activer les règles `prefer_const_constructors` et `prefer_const_literals_to_create_immutables` dans `analysis_options.yaml`, corriger les alertes ; utiliser `ref.watch(provider.select(...))` là où un seul champ est lu | Nombre d'alertes corrigées ; `flutter analyze` sans problème ; `flutter test` vert |
| P5 | Poids de l'application : lister les images de `mobile/assets/` de plus de 200 Ko et les compresser sans perte visible | Taille de l'APK (`flutter build apk --analyze-size`) avant et après |

Règles : un commit par tâche, aucune note chiffrée sans commande qui la produit, `flutter analyze` sans problème et `flutter test`
à 100 % avant chaque poussée.
