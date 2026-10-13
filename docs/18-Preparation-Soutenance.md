# Naatal Agro — Préparation de la soutenance : état prouvé du projet & grille de démonstration

| Informations | Valeur |
|--------------|---------|
| Projet | Naatal Agro |
| Document | Préparation de la soutenance (état prouvé et vérifié du projet) |
| Objectif | Réussir la soutenance avec une démonstration technique irréprochable et un rapport transparent |
| Règle d'or | Chaque affirmation « Fait » s'appuie sur une preuve concrète (207 tests backend, 55 tests Flutter, build Web). |

---

# 1. Principe Directeur

Une application prête pour la production se distingue d'un prototype par sa sécurité, sa cohérence des données, son interconnexion 360° et sa testabilité :

- **Élimination totale des données factices :** Plus aucun mock ou `math.Random` dans les graphes de prix ou les alertes. Toutes les cotations proviennent de la base réelle des 19 marchés sénégalais.
- **Interconnexion 360° prouvée :** Cultures ↔ Guides ISRA ↔ Récoltes ↔ Stock Inventaire ↔ Ventes ↔ Finances ↔ Météo ↔ Notifications.
- **Transparence totale devant le jury :** Les fonctionnalités réelles sont démontrées avec fierté ; les fonctionnalités futures (SMS OTP payant) sont clairement présentées comme perspectives assumées.

---

# 2. État par Domaine & Preuves Formelles

Légende : **Fait** = prouvé par des tests automatisés et compilation verte ; **Prévu** = documenté en perspective.

| Domaine | État | Preuve Technique | Reste / Perspective |
|---|---|---|---|
| **Authentification & Droits** | **Fait** | Jetons JWT à rotation, blacklist, changement MDP, isolation stricte par utilisateur (`apps/users`) | Régénération des secrets en environnement de production |
| **Confidentialité & RGPD / CDP** | **Fait** | Consentement enregistré, export complet JSON chiffré, suppression de compte (`apps/privacy`) + Écrans mobiles dédiés testés (`settings_security_test.dart`) | Désignation juridique formelle du DPO |
| **Interconnexion 360° Cultures & Guides** | **Fait** | Date de récolte auto-calculée selon le cycle ISRA ; liaison `Crop.guide` ; préchargement optimisé sans N+1 (`apps/agriculture`) | — |
| **Cycle Récolte ↔ Stock ↔ Vente** | **Fait** | Action `/crops/{id}/harvest/` incrémente le stock et notifie ; `/finances/sales/` décrémente le stock avec garde-fou anti-survente (`apps/finances/tests.py`) | Multi-devises (inutile en zone UEMOA) |
| **Marchés & Cotations** | **Fait** | 20 615 cotations historiques réelles sur 19 marchés sénégalais ; graphes mobiles et web branchés sans aucune simulation | — |
| **Assistant IA Contextuel** | **Fait** | Réponses prioritairement extraites des fiches ISRA sourcées, quotas anti-abus (30 req/h), bascule Groq/Gemini (`apps/ai_assistant`) | Clés de production à fournir au déploiement |
| **Mode Hors-ligne (Offline Sync)** | **Fait** | File d'attente FIFO SQLite avec rejeu automatique au retour réseau (`sync_service_test.dart`) | Cache de lecture persistant |
| **Tableau de Bord Web (React)** | **Fait** | Dashboard administrateur connecté à l'API DRF (`/api/dashboard/`, `/api/markets/prices/`), proxy Vite configuré, `npm run build` réussi sans erreur | Authentification SSO Admin |
| **Vérification SMS (OTP)** | **Simulé volontairement** | Écrans conservés avec avertissement honnête en attendant la souscription d'un agrégateur SMS (Orange/Wave) | Intégration passerelle SMS payante |
| **Tests & Qualité Globale** | **Fait** | **207 tests Backend Django (206 passés, 1 sauté, 0 échec)** + **55 tests Flutter (100% passés)** + `flutter analyze lib` (0 avertissement) | Tests E2E automatisés multi-devices |

---

# 3. Démonstration Type à Dérouler Devant le Jury (Scénario 360°)

1. **Création d'une culture liée à un guide officiel :**
   - L'agriculteur crée une parcelle d'oignon.
   - En sélectionnant le guide ISRA *Violet de Galmi*, la date de récolte prévisionnelle se calcule automatiquement (90-120 jours).
2. **Consultation des cours du marché réel :**
   - L'agriculteur consulte les prix réels de l'oignon sur le marché Tilène ou Castors via la courbe historique connectée (sans aucun `math.Random`).
3. **Enregistrement d'une récolte :**
   - L'agriculteur clique sur « Enregistrer la récolte » (ex: 500 kg).
   - Le statut passe à *Récolté*, le stock d'inventaire est automatiquement créé/incrémenté et une notification est émise.
4. **Vente du stock et impact financier :**
   - Depuis l'inventaire, l'agriculteur clique sur « Vendre ce stock » (ex: 200 kg à 350 FCFA/kg).
   - Le stock passe de 500 kg à 300 kg. La recette (+70 000 FCFA) est synchronisée dans le bilan financier.
5. **Démonstration du mode hors-ligne :**
   - Passage en mode avion sur le téléphone : ajout d'une tâche d'irrigation.
   - Reconnexion : synchronisation silencieuse et immédiate via le `SyncService`.
6. **Consultation du Tableau de Bord Web Administrateur :**
   - Ouverture du dashboard React montrant en direct les cotations nationales et les indicateurs consolidés.

---

# 4. Réponses Clés aux Questions du Jury

- **Q : Vos données de marché sont-elles fictives ?**
  *R :* Non. La base contient plus de 20 000 relevés historiques réels issus des marchés hebdomadaires et urbains du Sénégal (Dakar, Kaolack, Touba, Saint-Louis, etc.). Tous les graphiques sont alimentés par des requêtes DRF réelles.
- **Q : Que se passe-t-il si un agriculteur vend plus que son stock disponible ?**
  *R :* Le backend DRF bloque strictement la transaction avec une erreur HTTP 400 et le message « Stock insuffisant ». Les tests unitaires valident ce cas limite.
- **Q : Pourquoi le code SMS OTP passe-t-il avec n'importe quels 4 chiffres ?**
  *R :* C'est un choix d'architecture assumé : l'intégration d'un SMS gateway payant (type Twilio ou Orange API) est budgétée pour la phase de déploiement commercial. Tout le reste du flux d'authentification (JWT chiffré, révocation, hachage PBKDF2) est 100% réel et sécurisé.
- **Q : Comment garantissez-vous la conformité CDP / RGPD ?**
  *R :* Tout utilisateur peut télécharger l'intégralité de ses données en un clic (export JSON) ou demander la purge définitive de son compte avec confirmation de son mot de passe, conformément aux directives de la CDP du Sénégal.
