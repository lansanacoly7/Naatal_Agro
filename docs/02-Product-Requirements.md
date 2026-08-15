# 🌾 Nataal Agro — Product Requirements Document (PRD)

| Informations | Valeur |
|--------------|---------|
| Projet | Nataal Agro |
| Document | Product Requirements (PRD) |
| Version | 2.0 |
| Statut | Mise à jour |
| Dépend de | 01-Vision.md |
| Objectif | Définir les fonctionnalités et comportements du produit |

---

# 1. Objectif du document

Ce document définit :

- les fonctionnalités du produit
- les parcours utilisateurs
- les modules fonctionnels
- les règles métier
- la structure des versions (V1, V2, V3)

Il sert de référence unique pour le développement et l’évolution du produit.

---

# 2. Utilisateurs cibles

## 2.1 Utilisateur principal (V1)

- petits producteurs agricoles
- maraîchers
- producteurs céréaliers
- exploitants individuels

---

## 2.2 Utilisateurs secondaires (V2+)

- grandes exploitations
- commerçants agricoles
- acheteurs sur marchés
- institutions agricoles
- coopératives (phase future)

---

# 3. Parcours utilisateur global (cycle agricole)

Nataal Agro suit un cycle complet :

```text id="cycle_agri"
Préparer → Planter → Suivre → Surveiller → Récolter → Vendre

L’application doit accompagner chaque étape.

4. Architecture fonctionnelle du produit

Le produit est organisé en 5 domaines principaux :

4.1 🌱 Agriculture (Cœur du produit)
Fonctionnalités :
gestion des cultures
suivi des exploitations
calendrier agricole
journal d’activités
état de santé des cultures
Données :
type de culture
date de semis
localisation
cycle de vie
historique des actions
4.2 📊 Marchés (vision AgriSmart intégrée)
Fonctionnalités :
affichage des prix agricoles
comparaison entre marchés
évolution des prix
tendances (hausse / baisse)
recommandation de vente
Règle :

👉 Les marchés ne sont pas une simple info, mais un outil de décision économique.

4.3 🗺️ Carte des marchés
Fonctionnalités :
carte interactive
localisation des marchés
distance utilisateur
prix par zone
recommandations géographiques
Objectif :

“Où vendre pour optimiser revenu et distance ?”

4.4 🤖 Intelligence Artificielle (IA)
Fonctionnalités :
assistant conversationnel
recommandations agricoles
recommandations économiques
analyse contextuelle (culture + météo + marché)
Cas d’usage :
entretien des cultures
maladie des plantes
moment de récolte
moment optimal de vente
4.5 🔔 Notifications
Fonctionnalités :
alertes météo
alertes agricoles
alertes marché
rappels d’activités
alertes de récolte
4.6 👤 Utilisateur (Profil)
Fonctionnalités :
gestion du compte
localisation
préférences agricoles
cultures suivies
langue (FR / Wolof)
5. Module Dashboard (Accueil)
Rôle principal :

Répondre à : “Que dois-je faire aujourd’hui ?”

Contenu :
météo locale
actions prioritaires
état des cultures
marchés importants
alertes critiques
conseils IA
6. Fonctionnalités par version
6.1 Version 1 (V1 — CORE PRODUIT)
Objectif :

Assurer le cycle agricole complet de base.

Modules :
Authentification
Dashboard
Agriculture (cultures)
Marchés
Carte des marchés
IA basique
Notifications
Profil
6.2 Version 2 (V2 — INTELLIGENCE & OPTIMISATION)
Ajouts :
IA avancée contextuelle
historique des cultures
analyses de rendement
statistiques agricoles
amélioration prédictive des prix
recommandations multi-facteurs
6.3 Version 3 (V3 — ECOSYSTEM AGRICOLE)
Ajouts :
marketplace agricole
coopératives
paiement mobile money
intégration institutions agricoles
IoT agricole
analyse satellite
7. Règles fonctionnelles
7.1 Simplicité UX
1 écran = 1 objectif
maximum 3 actions principales par écran
réduction des décisions inutiles
7.2 Rapidité d’accès
information accessible en ≤ 3 clics
dashboard immédiat
7.3 Offline-first (important)

Fonctionnalités accessibles hors connexion :

cultures
calendrier agricole
historique local
consultation des données récentes
7.4 Séparation des données
chaque utilisateur a ses propres données
isolation complète des profils
synchronisation backend sécurisée
8. Contraintes techniques
application mobile Android (priorité Flutter)
backend REST API (Django)
faible consommation réseau
optimisation performance mobile
architecture modulaire évolutive
9. Cas d’usage principaux
UC1 — Ajouter une culture
utilisateur ouvre “Produits”
crée une culture
ajoute informations (type, date, localisation)
sauvegarde
UC2 — Suivre une culture
utilisateur consulte une culture
met à jour état
ajoute activité (arrosage, traitement, etc.)
UC3 — Consulter les marchés
utilisateur ouvre “Marchés”
compare prix entre zones
consulte tendances
prend décision de vente
UC4 — Utiliser la carte
utilisateur ouvre carte
visualise marchés proches
compare distances et prix
UC5 — Utiliser l’IA
utilisateur pose question
IA analyse contexte (culture + météo + marché)
retourne recommandation actionnable
10. Règle produit centrale

Toute fonctionnalité doit répondre à au moins un objectif :

produire mieux
décider mieux
vendre mieux

Sinon elle est exclue.

11. Conclusion

Ce PRD définit la structure fonctionnelle complète de Nataal Agro.

Il transforme le produit en une plateforme agricole intelligente centrée sur le cycle de décision complet du producteur, intégrant à la fois la production agricole et la dimension économique des marchés.


---

# 🧠 Ce que tu viens de gagner avec cette version

### ✔ Fusion propre des deux visions
### ✔ suppression du “PRD catalogue” → remplacé par “PRD système”
### ✔ cycle agricole explicite (ultra important pour UX)
### ✔ séparation claire des modules métier
### ✔ IA repositionnée correctement (multi-domaines)
### ✔ base parfaite pour backend Django + Flutter

