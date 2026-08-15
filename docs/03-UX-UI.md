
# 🌾 Nataal Agro — UX / UI Design System

| Informations | Valeur |
|--------------|---------|
| Projet | Nataal Agro |
| Document | UX / UI Specification |
| Version | 2.0 |
| Statut | Mise à jour |
| Dépend de | 02-Product-Requirements.md |
| Objectif | Définir l’expérience utilisateur et le design system |

---

# 1. Objectif du design

L’objectif UX/UI de Nataal Agro est de créer une application :

- compréhensible en moins de 5 secondes
- utilisable par des non-techniciens
- adaptée au contexte agricole réel (terrain, faible connexion)
- centrée sur les décisions agricoles et économiques
- rapide et orientée action

---

# 2. Principes UX fondamentaux

---

## 2.1 Simplicité extrême

- 1 écran = 1 objectif principal
- suppression du superflu
- hiérarchie visuelle stricte

---

## 2.2 Action-first design

Chaque écran doit répondre à :

> “Quelle action dois-je faire maintenant ?”

Pas seulement “qu’est-ce que je vois”.

---

## 2.3 Accessibilité terrain

- gros éléments cliquables
- contraste élevé (soleil / extérieur)
- texte court et clair
- icônes explicites
- compatibilité low-end Android

---

## 2.4 Rapidité cognitive

- décision immédiate en haut de l’écran
- suppression des choix inutiles
- information priorisée par impact

---

# 3. Navigation principale (Flutter)

```text id="nav_ui_v2"
🏠 Accueil
🌾 Produits (Cultures)
💰 Marchés
🗺️ Carte
🤖 IA
👤 Profil
````

---

# 4. Structure des écrans

---

## 4.1 🏠 Accueil (Dashboard)

### Objectif :

> “Que dois-je faire aujourd’hui ?”

---

### Contenu :

* météo du jour
* actions prioritaires agricoles
* état des cultures
* alertes importantes
* recommandations IA
* aperçu marché clé du jour

---

### Logique UX :

Le dashboard est un **centre de décision**, pas un tableau de données.

---

## 4.2 🌾 Produits (Cultures)

### Objectif :

Suivre ses cultures et leur cycle de vie.

---

### UI :

* liste de cultures sous forme de cartes
* statut visuel :

🟢 bon état
🟠 attention
🔴 critique

---

### Carte culture :

* nom de la culture
* progression (% cycle)
* dernière activité
* prochaine action recommandée

---

## 4.3 🌱 Détail Culture

### Sections :

* vue générale
* cycle agricole (timeline)
* journal d’activités
* recommandations IA
* statistiques simples

---

### Extension AgriSmart intégrée :

* estimation de valeur de la récolte
* tendance du marché lié à cette culture

---

## 4.4 💰 Marchés

### Objectif :

> “Quand et où vendre ?”

---

### UI :

* liste des produits agricoles
* prix par marché
* variation (↑ ↓)
* recommandation de vente IA

---

### Logique :

Le marché n’est pas informatif, il est **décisionnel**.

---

## 4.5 🗺️ Carte des marchés

### UI :

* carte interactive du Sénégal
* marchés localisés
* prix par zone
* distance utilisateur
* filtres par produit

---

### Objectif :

> “Où vendre pour optimiser revenu + distance”

---

## 4.6 🤖 IA (Assistant agricole)

### Objectif :

Assistant contextuel global.

---

### UI :

* zone de chat
* raccourcis rapides :

🌱 Culture
💬 Question
📷 Analyse image

---

### Capacité IA :

* agriculture (maladies, entretien)
* marché (vente optimale)
* météo (actions recommandées)
* planification agricole

---

## 4.7 👤 Profil

### Contenu :

* informations utilisateur
* localisation
* cultures suivies
* préférences
* langue (FR / Wolof)
* paramètres système

---

# 5. Design System

---

## 5.1 Couleurs (optimisé terrain)

### Couleur principale :

* Vert agricole : `#2E7D32`

### Secondaires :

* Terre : `#A1887F`
* Beige clair : `#F5F5F5`
* Blanc : `#FFFFFF`

### États :

* Vert = succès
* Orange = attention
* Rouge = danger

---

## 5.2 Typographie

* Inter / Roboto
* Titres : Bold
* Texte : Regular
* Hiérarchie simple et forte

---

## 5.3 Composants UI

### Boutons :

* grands
* arrondis
* texte court

---

### Cards :

* ombre légère
* coins arrondis
* contenu structuré

---

### Inputs :

* simples
* placeholders explicites
* validation rapide

---

# 6. Design des interactions

---

## 6.1 Règle des 2 clics

Toute action importante doit être accessible en ≤ 2 clics.

---

## 6.2 Feedback utilisateur

Chaque action doit avoir :

* loading clair
* confirmation
* erreur compréhensible

---

## 6.3 Micro-interactions

* animations légères
* transitions fluides
* feedback immédiat

---

# 7. Mobile-first design

Optimisé pour :

* Android low-end
* faible connexion
* usage terrain
* forte luminosité extérieure

---

# 8. Wireframe logique (flux)

```text id="flow_ui"
App open
   ↓
Accueil (décision du jour)
   ↓
Produits / Marchés / Carte / IA
   ↓
Détail action
   ↓
Retour dashboard
```

---

# 9. IA dans l’UX

L’IA n’est pas un écran isolé.

Elle est :

* intégrée dans le dashboard
* accessible depuis chaque module
* contextuelle selon l’écran

---

# 10. Erreurs UX à éviter

* surcharge d’informations
* écrans trop profonds (>3 niveaux)
* jargon technique agricole
* séparation IA / produit (interdit)
* menus complexes

---

# 11. Conclusion

Le design de Nataal Agro est conçu pour :

* guider les décisions agricoles
* réduire la complexité terrain
* intégrer marché + agriculture + IA
* fonctionner dans des conditions réelles africaines

---

# 🧠 Résultat produit

Nataal Agro n’est pas une application agricole classique.

C’est une **interface de décision agricole intelligente**, centrée sur l’action et le résultat.

```

---

# 🧠 Ce qu’on vient d’améliorer (important)

### ✔ fusion UX agriculture + marché propre
### ✔ IA intégrée (pas isolée)
### ✔ carte repositionnée comme outil décisionnel
### ✔ suppression des “features UI gadgets”
### ✔ UX beaucoup plus “terrain Sénégal réel”
### ✔ cohérence parfaite avec PRD + Vision

