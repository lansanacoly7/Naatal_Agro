# Nataal Agro — UX / UI Design System

| Informations | Valeur |
|--------------|---------|
| Projet | Nataal Agro |
| Document | UX / UI Specification |
| Version | 1.0 |
| Statut | En cours |
| Dépend de | 02-Product-Requirements.md |
| Objectif | Définir l’expérience utilisateur et le design system |

---

# 1. Objectif du design

L’objectif UX/UI de Nataal Agro est de créer une application :

- simple à comprendre en moins de 5 secondes
- utilisable par des utilisateurs non techniques
- rapide et fluide
- centrée sur les actions et décisions
- adaptée aux réalités agricoles du Sénégal

---

# 2. Principes UX fondamentaux

## 2.1 Simplicité extrême

- 1 écran = 1 objectif principal
- suppression du superflu
- hiérarchie visuelle claire

---

## 2.2 Action-first design

L’utilisateur ne doit jamais chercher quoi faire.

Chaque écran répond à :
> “Quelle action dois-je faire maintenant ?”

---

## 2.3 Accessibilité terrain

- gros boutons
- texte lisible
- icônes explicites
- faible dépendance au texte long

---

## 2.4 Rapidité cognitive

- informations essentielles en haut
- décisions rapides
- réduction des choix inutiles

---

# 3. Navigation principale (Flutter)

```text id="nav_ui"
🏠 Accueil
🌾 Produit
💰 Marchés
🤖 IA
👤 Profil
4. Structure des écrans
4.1 Accueil (Dashboard)
Objectif :

Donner une réponse immédiate à :

“Que dois-je faire aujourd’hui ?”

Contenu :
météo du jour
alertes importantes
action recommandée
prix du marché clé
accès rapide IA
UI :
cartes empilées
couleurs simples
priorité visuelle forte sur les actions
4.2 Produit
Objectif :

Suivre ses cultures facilement

UI :
liste de cartes cultures
statut visuel :
🟢 bon état
🟠 attention
🔴 critique
Carte culture :
nom culture
progression (%)
prochaine action
bouton “voir détails”
4.3 Détail Produit
Sections :
Vue générale
Calendrier agricole
Journal d’activité
Conseils IA
Statistiques simples
4.4 Marchés
Objectif :

Aider à décider où vendre

UI :
liste de prix par produit
variation (↑ ↓)
comparaison villes
4.5 Carte des marchés
UI :
carte interactive du Sénégal
points marchés
prix affichés par zone
filtres produits
4.6 IA (Assistant)
Objectif :

Aide rapide et contextuelle

UI :
zone de question
boutons rapides :
🌱 Diagnostic
💬 Question
📷 Image
chat en dessous
4.7 Profil
Contenu :
informations utilisateur
localisation
cultures suivies
paramètres
langue
sécurité
5. Design System
5.1 Couleurs
Couleur principale :
Vert agricole (#2E7D32)
Couleurs secondaires :
Terre (#A1887F)
Beige clair (#F5F5F5)
Blanc (#FFFFFF)
Couleurs état :
Vert = succès
Orange = attention
Rouge = danger
5.2 Typographie
Police principale : Inter / Roboto
Titre : Bold
Texte : Regular
Hiérarchie claire
5.3 Composants UI
Boutons :
arrondis
grandes tailles
texte court
Cards :
ombre légère
coins arrondis
informations structurées
Inputs :
simples
placeholders explicites
validation instantanée
6. Design des interactions
6.1 Règle des 2 clics

Toute action importante doit être accessible en maximum 2 clics.

6.2 Feedback utilisateur

Chaque action doit avoir un retour visuel :

chargement
confirmation
erreur claire
6.3 Micro-interactions
animation légère sur boutons
transition fluide entre écrans
feedback visuel immédiat
7. Mobile-first design

L’application est conçue pour :

petits écrans Android
connexion faible
usage terrain
8. Wireframe logique (texte)
Flow principal utilisateur :
App open
   ↓
Accueil (actions du jour)
   ↓
Produit / Marchés / IA
   ↓
Détail / Action
   ↓
Retour dashboard
9. Expérience IA

L’IA doit être intégrée comme :

un assistant accessible partout
pas un simple écran séparé
un outil contextuel
10. Erreurs UX à éviter
trop de texte sur un écran
menus complexes
navigation profonde (>3 niveaux)
jargon technique agricole
surcharge d’informations
11. Conclusion

Le design de Nataal Agro est conçu pour :

guider l’utilisateur
réduire la complexité agricole
accélérer la prise de décision
fonctionner dans des conditions réelles de terrain

---

# 🧠 Ce qu’on vient de construire

✔ Architecture produit complète  
✔ Vision  
✔ PRD  
✔ UX/UI system  

👉 Là, ton projet commence déjà à ressembler à un **produit industriel réel**

---

# 🚀 Prochaine étape

👉 `04-Architecture-System.md`

Et là on va entrer dans le niveau **ingénierie logicielle pure** :

- communication Flutter ↔ Django
- structure API
- auth system
- flux de données
- IA integration
- carte + géolocalisation
- sécurité globale
