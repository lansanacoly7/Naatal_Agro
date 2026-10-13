# Naatal Agro — Feuille de Route & Spécifications des Tâches pour Pathé Fall

| Informations | Valeur |
|--------------|---------|
| Destinataire | Pathé Fall |
| Date | 13 Octobre 2026 |
| Contexte | Suite de l'audit complet (branche `test`) et des correctifs P0 réalisés par Antigravity |
| Objectif | Éliminer les dernières données factices, sécuriser la robustesse mobile/backend et préparer la livraison |
| Statut initial | Tests Backend : 210/210 verts. Tests Flutter : 55/55 verts. Flutter analyze : 0 erreur. |

---

## 1. Contexte & Travail Déjà Effectué (P0)

Les bloquants critiques suivants ont été résolus et validés sur la branche `test` :
- **Vente de stock (Crash HTTP 500) :** Corrigé dans `SaleSerializer` et `SaleViewSet`.
- **Culture fantôme de 1 ha :** Éliminée. Les ventes de stock manuel n'inventent plus de parcelles.
- **Transactions financières :** Création atomique de `Transaction(income)` liée à chaque vente et restitution du stock en cas de suppression de vente.
- **Mise à jour du profil (`full_name`) :** Fonctionnelle via `PATCH /api/users/me/` avec mise à jour automatique de `first_name` et `last_name`.
- **Mode hors-ligne :** Prise en compte du code `HTTP 202 Accepted` par les providers mobile et purge de la file d'attente à la déconnexion.
- **Permissions Android :** `INTERNET` et `ACCESS_NETWORK_STATE` ajoutés au manifeste principal.
- **Route agronomique :** Lien de navigation corrigé vers `/agriculture/guides/:slug`.

---

## 2. Liste des Tâches Assignées à Pathé Fall

---

### Tâche 1 : Nettoyage des étiquettes et données trompeuses des Marchés

**Priorité :** Haute  
**Fichiers concernés :**
- `mobile/lib/features/markets/presentation/screens/product_detail_screen.dart`
- `mobile/lib/features/markets/presentation/screens/market_comparison_screen.dart`
- `mobile/lib/features/markets/presentation/screens/market_detail_screen.dart`
- `mobile/lib/features/dashboard/presentation/widgets/market_prices_section.dart`

**Spécifications :**
1. **Remplacement des mentions trompeuses :**
   - Remplacer « *Cotations Officielles Sénégal* », « *Source : SIM / CSA Sénégal* » et « *Marché certifié* » par « *Relevés indicatifs de marché* ».
   - Supprimer la mention « *enregistrés en temps réel...* » si la date du relevé n'est pas celle du jour.
2. **Nettoyage de l'écran Fiche Marché (`market_detail_screen.dart`) :**
   - **Itinéraire GPS :** Retirer les valeurs en dur « *≈ 18 km, ≈ 25 min, ≈ 3 500 FCFA/sac* » répétées à l'identique pour les 19 marchés. Remplacer par un état indicatif : « *Calcul d'itinéraire non disponible (nécessite la géolocalisation active)* ». Désactiver ou lier le bouton « *Démarrer l'itinéraire GPS* » vers une URL `geo:` ou Google Maps externe avec les coordonnées réelles du marché.
   - **Variation de prix :** Supprimer le texte fixe « *+8,4 % / −5,2 % sur 7 jours* » et le dessin Sparkline figé lorsqu'aucun historique n'est calculé dynamiquement.
   - **Informations répétées :** Remplacer les textes codés en dur (« *Routes goudronnées* », « *Mis à jour aujourd'hui 08:30* ») par des données dynamiques ou un état générique sobre.
3. **Prix de repli (Fallbacks) :**
   - Dans `market_prices_section.dart` et `product_detail_screen.dart`, ne plus afficher un faux prix de secours arbitraire (450 FCFA ou 350 FCFA) si la base ne contient aucun relevé : afficher explicitement « *Prix non renseigné* » ou « *Aucun relevé disponible* ».

---

### Tâche 2 : Clarification des Dialogues d'Authentification (Mot de passe oublié & OTP)

**Priorité :** Haute  
**Fichiers concernés :**
- `mobile/lib/features/auth/presentation/screens/login_screen.dart` (ligne ~115)
- `mobile/lib/features/auth/presentation/screens/register_screen.dart` (ligne ~106)

**Spécifications :**
1. **Dialogue « Mot de passe oublié » :**
   - Le dialogue affiche actuellement « *Instructions SMS envoyées* » alors qu'aucun SMS n'est émis.
   - Remplacer le message par :  
     > *« La réinitialisation automatique par SMS est en attente d'intégration de la passerelle opérateur. Veuillez contacter le support ou votre administrateur pour réinitialiser votre accès. »*
2. **Validation OTP d'inscription :**
   - L'écran accepte n'importe quel code à 4 chiffres.
   - Ajouter un bandeau informatif honnête au-dessus du champ OTP :  
     > *« Mode démonstration : saisissez un code à 4 chiffres pour valider l'inscription. »*

---

### Tâche 3 : Sécurisation du Dialogue d'Édition de Culture (Statut `attention`)

**Priorité :** Moyenne  
**Fichiers concernés :**
- `mobile/lib/features/agriculture/presentation/screens/crops_list_screen.dart`
- `mobile/lib/features/agriculture/presentation/screens/crop_detail_screen.dart`

**Spécifications :**
- Le seed de données contient parfois des cultures avec le statut `attention`.
- Le dialogue d'édition plante actuellement si `crop.status == 'attention'` car le DropdownMenu n'attendait que `active` ou `harvested`.
- Ajouter l'option `attention` (« Surveillance requise ») dans la liste des choix possibles ou mapper automatiquement `attention` vers `active` lors de l'ouverture du formulaire.

---

### Tâche 4 : Fallbacks et Sécurisation des 5 Images Référencées

**Priorité :** Moyenne  
**Fichiers concernés :**
- `mobile/assets/images/`
- Catalogue produits et widgets utilisant `DecorationImage`

**Spécifications :**
- 5 images sont référencées dans les produits mais absentes du dossier assets : `fraise.png`, `mais.png`, `mil.jpg`, `pomme.png`, `riz.png`.
- Ajouter un widget d'affichage d'image sécurisé avec `errorBuilder` ou `Image.asset(..., errorBuilder: (ctx, err, stack) => Icon(Icons.eco, color: AppColors.primary))` pour éviter tout carré d'erreur lors du défilement des listes.

---

### Tâche 5 : Pagination par Défaut de l'API des Prix (`/api/markets/prices/`)

**Priorité :** Haute  
**Fichier concerné :**
- `backend/apps/markets/views.py`

**Spécifications :**
- Actuellement, un `GET /api/markets/prices/` sans paramètre de pagination tente de sérialiser 20 615 lignes (4,3 Mo).
- Dans `PriceViewSet`, configurer une pagination standard :
  ```python
  from rest_framework.pagination import PageNumberPagination

  class StandardPricePagination(PageNumberPagination):
      page_size = 20
      page_size_query_param = 'page_size'
      max_page_size = 100

  class PriceViewSet(viewsets.ReadOnlyModelViewSet):
      queryset = Price.objects.all().select_related('market')
      serializer_class = PriceSerializer
      pagination_class = StandardPricePagination
      permission_classes = [permissions.AllowAny]
  ```
- Vérifier que les tests de `apps.markets` continuent de passer avec `python manage.py test apps.markets`.

---

### Tâche 6 : Configuration du Modèle Gemini dans `settings/base.py`

**Priorité :** Moyenne  
**Fichier concerné :**
- `backend/core/settings/base.py` (ligne ~22)

**Spécifications :**
- La variable par défaut est configurée sur `gemini-3.8-flash` (version fictive/inexistante).
- Remplacer par :
  ```python
  GEMINI_MODEL = env('GEMINI_MODEL', default='gemini-2.5-flash')
  ```
- S'assurer de la cohérence avec `ai/README.md`.

---

### Tâche 7 : Sécurisation Concurrence du Refresh Token (`api_client.dart`)

**Priorité :** Moyenne  
**Fichier concerné :**
- `mobile/lib/core/network/api_client.dart`

**Spécifications :**
- En cas de 401 sur deux requêtes simultanées (ex: tableau de bord au démarrage), deux appels `_refreshToken()` partent en parallèle. Le premier fait tourner le refresh token, ce qui fait échouer le second et provoque une déconnexion intempestive.
- Ajouter un verrou via un `Completer<bool>? _refreshCompleter` :
  ```dart
  Completer<bool>? _refreshCompleter;

  Future<bool> _refreshToken() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }
    _refreshCompleter = Completer<bool>();
    try {
      final success = await _performTokenRefresh();
      _refreshCompleter!.complete(success);
      return success;
    } catch (e) {
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }
  ```

---

### Tâche 8 : Dockerfile & staticfiles

**Priorité :** Faible (Avant déploiement VPS)  
**Fichiers concernés :**
- `backend/Dockerfile`
- `docker-compose.yml`

**Spécifications :**
1. Dans le `Dockerfile`, entourer de guillemets les versions de dépendances : `"gunicorn>=22.0.0"`.
2. Créer le dossier `/app/staticfiles` avec les permissions utilisateur `appuser` avant le switch `USER appuser` :
   ```dockerfile
   RUN mkdir -p /app/staticfiles && chown -R appuser:appuser /app/staticfiles
   ```

---

## 3. Critères d'Acceptation & Commandes de Validation

Avant chaque commit de Pathé :
1. **Tests Backend :**
   ```powershell
   .\venv\Scripts\python.exe manage.py test
   ```
   *Critère : 100% des tests doivent être verts.*
2. **Analyse Statique Flutter :**
   ```powershell
   cd mobile
   flutter analyze lib
   ```
   *Critère : 0 erreur, 0 avertissement.*
3. **Tests Flutter :**
   ```powershell
   flutter test
   ```
   *Critère : 55 tests ou plus, tous passés.*
4. **Format de Commit :**
   Respecter strictement la convention :  
   `fix(markets): nettoyage des donnees factices et fallbacks de prix`  
   `feat(pagination): pagination standard sur l'api des cotations de marche`
