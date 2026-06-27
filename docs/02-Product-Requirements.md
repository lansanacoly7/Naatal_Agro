# Nataal Agro — Product Requirements Document (PRD)

| Informations | Valeur |
|--------------|---------|
| Projet | Nataal Agro |
| Document | Product Requirements (PRD) |
| Version | 1.0 |
| Statut | En cours |
| Dépend de | 01-Vision.md |
| Objectif | Définir les fonctionnalités et comportements du produit |

---

# 1. Objectif du document

Ce document définit :

- les fonctionnalités du produit
- les besoins utilisateurs
- les cas d’utilisation
- les règles fonctionnelles
- la structure des versions (V1, V2, V3)

Il sert de référence principale pour le développement.

---

# 2. Utilisateurs cibles

## 2.1 Utilisateur principal (V1)

- petits producteurs agricoles
- maraîchers
- producteurs céréaliers
- exploitants individuels

---

## 2.2 Utilisateurs futurs

- grandes exploitations
- coopératives
- institutions agricoles
- acheteurs / marchés

---

# 3. Parcours utilisateur principal

## 3.1 Onboarding

1. Création de compte
2. Choix des cultures
3. Localisation
4. Configuration simple

---

## 3.2 Utilisation quotidienne

1. Ouvrir l’app
2. Voir les actions du jour
3. Consulter météo
4. Vérifier marché
5. Demander conseil IA
6. Recevoir alertes

---

# 4. Fonctionnalités globales

## 4.1 Accueil (Dashboard)

### Fonctionnalités :
- résumé du jour
- météo locale
- alertes importantes
- actions recommandées
- prix clés du marché

### Règle :
👉 L’accueil doit répondre à :
> “Que dois-je faire aujourd’hui ?”

---

## 4.2 Module Produits (Agriculture)

### Fonctionnalités :
- ajouter une culture
- suivre l’état de croissance
- visualiser calendrier agricole
- journal des activités
- statut santé culture

### Données associées :
- type de culture
- date de semis
- localisation
- cycle de vie
- actions effectuées

---

## 4.3 Module Marchés

### Fonctionnalités :
- affichage des prix des produits
- comparaison entre marchés
- évolution des prix
- recommandation de vente

### Exemple :
- tomate : Dakar vs Kaolack
- prix actuel
- tendance (↑ ↓)

---

## 4.4 Module Carte des marchés

### Fonctionnalités :
- carte interactive
- localisation des marchés
- prix par zone
- recommandation géographique

### Règle :
👉 La carte doit aider à répondre :
> “Où dois-je vendre ?”

---

## 4.5 Module IA (Assistant agricole)

### Fonctionnalités :
- chat IA
- conseils agricoles
- recommandations quotidiennes
- réponses contextualisées

### Cas d’usage :
- “Que dois-je faire aujourd’hui ?”
- “Ma plante est malade”
- “Quand dois-je récolter ?”

---

## 4.6 Module Notifications

### Fonctionnalités :
- alertes météo
- alertes agricoles
- alertes marché
- rappels d’actions

---

## 4.7 Module Profil utilisateur

### Fonctionnalités :
- informations personnelles
- localisation
- cultures suivies
- préférences
- langue (FR / Wolof)

---

# 5. Fonctionnalités par version

---

## 5.1 Version 1 (V1 — CORE)

### Modules inclus :
- Authentification
- Dashboard (Accueil)
- Produits agricoles
- Marchés
- Carte des marchés
- IA simple
- Notifications
- Profil

---

## 5.2 Version 2 (V2 — EXPANSION)

- IA avancée (analyse contexte complet)
- historique de production
- statistiques agricoles
- prédiction météo avancée
- amélioration des marchés

---

## 5.3 Version 3 (V3 — ECOSYSTEM)

- marketplace agricole
- coopératives
- paiement mobile money
- extension institutionnelle
- analyse satellite
- IoT agricole

---

# 6. Règles fonctionnelles

## 6.1 Simplicité

Chaque écran doit avoir :
- 1 objectif principal
- maximum 3 actions principales

---

## 6.2 Rapidité

- accès aux informations en moins de 3 clics
- affichage instantané du dashboard

---

## 6.3 Offline-first (important)

Certaines fonctionnalités doivent fonctionner sans internet :
- consultation cultures
- calendrier
- historique local

---

## 6.4 Données utilisateur

Chaque utilisateur doit avoir :
- données isolées
- accès sécurisé
- synchronisation backend

---

# 7. Contraintes techniques

- application mobile principalement Android
- backend REST API
- support réseau faible
- optimisation performance mobile

---

# 8. Cas d’usage principaux

---

## UC1 — Ajouter une culture

Utilisateur :
- sélectionne “Produit”
- clique “Ajouter”
- choisit culture
- sauvegarde

Résultat :
- culture ajoutée au système

---

## UC2 — Consulter le marché

Utilisateur :
- ouvre “Marchés”
- consulte prix
- compare villes

Résultat :
- décision de vente optimisée

---

## UC3 — Demander conseil IA

Utilisateur :
- ouvre IA
- pose question

Résultat :
- recommandation agricole contextualisée

---

## UC4 — Consulter carte

Utilisateur :
- ouvre carte
- visualise marchés
- compare prix

Résultat :
- choix de lieu de vente

---

# 9. Règle produit centrale

👉 Toute fonctionnalité doit répondre à au moins un de ces besoins :

- produire mieux
- vendre mieux
- décider mieux

Sinon elle est exclue.

---

# 10. Conclusion

Ce PRD définit les fondations fonctionnelles de Nataal Agro.

Il garantit :
- cohérence produit
- simplicité utilisateur
- évolutivité technique
- clarté pour le développement