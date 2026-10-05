# Nataal Agro — AI System Architecture

| Informations | Valeur |
|--------------|---------|
| Projet | Nataal Agro |
| Document | AI System Architecture |
| Version | 2.0 |
| Statut | Corrigé |
| Dépend de | 08-Web-React.md |
| Objectif | Définir un système IA agricole scalable et fiable |

---

# 1. Rôle réel de l’IA

L’IA de Nataal Agro est un **moteur de décision agricole contextualisé**.

Elle ne doit pas :

- répondre comme un chatbot générique
- donner des informations vagues
- fonctionner hors contexte

Elle doit :

- analyser des données agricoles réelles
- produire des décisions actionnables
- adapter les recommandations au Sénégal
- utiliser les données backend (marchés, météo, cultures)

---

# 2. Principe fondamental

> L’IA est un système de décision, pas un générateur de texte.

Chaque réponse doit aider à :

- produire mieux
- vendre mieux
- décider mieux

---

# 3. Architecture IA globale

```text id="ai_arch_v2"
Flutter / React
        ↓
Django AI Gateway
        ↓
Context Builder Service
        ↓
AI Router
   ├── Gemini (analyse profonde)
   ├── Groq (réponses rapides)
        ↓
Post-processing Layer
        ↓
Structured Response API
        ↓
Frontend
````

---

# 4. AI Gateway (Backend Django)

Responsabilités :

* réception requête utilisateur
* enrichissement du contexte
* sélection du modèle IA
* sécurisation prompt injection
* logging complet

---

# 5. Context Engine (CRITIQUE)

Avant chaque requête IA :

```text id="ai_context_v2"
- utilisateur (profil, localisation)
- culture(s)
- météo actuelle
- prix marché
- historique utilisateur
- saison agricole
```

👉 Sans ce contexte = réponse invalide

---

# 6. AI Router (logique décisionnelle)

```text id="ai_router_v2"
IF request_complexity == HIGH:
    use Gemini
ELSE:
    use Groq
```

Critères de complexité :

* analyse multi-facteurs
* prévision
* diagnostic agricole

---

# 7. Types de requêtes IA

---

## 7.1 Conseil agricole

Ex :

> “Quand arroser mes tomates ?”

---

## 7.2 Diagnostic maladie

Ex :

> “Mes feuilles deviennent jaunes”

---

## 7.3 Décision marché

Ex :

> “Dois-je vendre maintenant ou attendre ?”

---

## 7.4 Impact météo

Ex :

> “Puis-je traiter aujourd’hui ?”

---

# 8. Prompt Engineering System

---

## 8.1 Prompt système global

```text id="prompt_v2"
Tu es un assistant agricole intelligent basé au Sénégal.

Tu aides les agriculteurs à prendre des décisions concrètes.

Règles :
- réponses simples
- action immédiate
- pas de théorie inutile
- contexte local obligatoire
```

---

## 8.2 Structure standard prompt

```text id="prompt_structure_v2"
CONTEXT:
- culture
- météo
- marché
- localisation

TASK:
- décision agricole

OUTPUT:
- action claire
```

---

# 9. Pipeline IA complet

```text id="ai_pipeline_v2"
User Input
   ↓
Django AI Gateway
   ↓
Context Builder
   ↓
AI Router (Gemini / Groq)
   ↓
Post Processing
   ↓
Structured JSON Response
   ↓
Frontend Display
```

---

# 10. Format de réponse IA (STANDARD)

```json id="ai_response_v2"
{
  "answer": "texte simple",
  "recommendation": "action concrète",
  "risk_level": "low | medium | high",
  "confidence": 0.0,
  "data_sources": {
    "market": true,
    "weather": true,
    "crop": true
  }
}
```

---

# 11. Sécurité IA

* protection prompt injection
* validation backend obligatoire
* logs complets des requêtes
* limitation taux requêtes
* filtrage contenu dangereux

---

# 12. Optimisation IA

* cache réponses fréquentes
* fallback Groq si Gemini lent
* réduction taille prompts
* réponses courtes par défaut
* batching context data

---

# 13. Limites strictes IA

L’IA ne doit jamais :

* inventer des prix de marché
* répondre sans contexte agricole
* donner des certitudes absolues
* remplacer données backend
* fonctionner hors Sénégal/Afrique Ouest (sauf config future)

---

# 14. Observabilité IA (AJOUT IMPORTANT)

Système de suivi :

* nombre requêtes IA
* coût Gemini vs Groq
* performance réponses
* taux satisfaction utilisateur
* types de questions fréquentes

---

# 15. Évolution IA

---

## Phase 1 (actuelle)

* chat agricole
* conseils simples
* diagnostic basique

---

## Phase 2

* prédiction rendement
* optimisation ventes
* analyse multi-facteurs

---

## Phase 3

* IA multi-agents agricoles
* simulation économie agricole
* assistant vocal Wolof
* analyse satellite

---

# 16. Rôle stratégique

L’IA est le cœur différenciateur de Nataal Agro :

> elle transforme des données agricoles en décisions exploitables en temps réel

---

# 17. Conclusion

Le système IA de Nataal Agro est :

* contextuel
* sécurisé
* scalable
* multi-modèles (Gemini + Groq)
* orienté décision terrain

```

---

# 🧠 Ce que j’ai amélioré

✔ AI Gateway réel (pas juste concept)  
✔ Context Engine obligatoire (très important)  
✔ Router logique clair  
✔ Format réponse standardisé  
✔ Observabilité IA (niveau produit sérieux)  
✔ limites anti-hallucination renforcées  
✔ évolution multi-agents structurée  

---

---

# 18. Connaissances de l'assistant : base d'abord, validation humaine ensuite

Cette section décrit ce qui est implémenté et fait foi pour la partie « réponses sourcées ».

## 18.1 Ordre de priorité

1. **Nos fiches agronomiques** (table `AgronomicGuide`, voir `docs/06-Backend-API.md` §7.3). Le serveur reconnaît la culture
   (nom, alias, nom scientifique, mots entiers uniquement) et le sujet demandé (semis, fertilisation, maladies, eau,
   récolte, rendement, cycle), puis renvoie les sections correspondantes avec leurs sources. Sans sujet précis, la fiche complète.
2. **Information absente de la fiche** : l'assistant le dit explicitement (« non disponible dans nos fiches vérifiées »).
   Il ne devine jamais une dose, un produit ou une date.
3. **Culture sans fiche, photo ou sujet hors fiches** : conseil général, marqué `origin = general` et accompagné d'un avertissement.

## 18.2 Garde-fous

- La recherche dans les fiches est déterministe : sans appel externe, sans SQL, sans dépendance au modèle de langage.
- Le modèle de langage ne reçoit que les fiches retrouvées, avec l'instruction de ne rien ajouter et de citer ses sources.
  Sa réponse est **refusée** si elle ne cite aucune source existante ; les repères inventés sont retirés. Dans ce cas (ou si le
  modèle est indisponible), la réponse est construite directement depuis les fiches.
- Les repères de source sont renumérotés pour que plusieurs fiches dans une même réponse restent cohérentes.
- Le profil de l'exploitant n'est jamais mélangé aux fiches : seules ses propres données sont transmises.

## 18.3 Alimenter la base : file de validation

Une information nouvelle n'entre dans une fiche qu'après validation humaine :

1. Elle est enregistrée comme `KnowledgeProposal` (champ visé, texte, **extrait exact** de la source, titre, éditeur, année, URL).
2. Dans l'administration Django, un relecteur compare le texte à l'extrait puis approuve ou rejette (actions groupées).
3. L'approbation est refusée si l'URL n'est pas en https sur un domaine de la liste `TRUSTED_WEB_DOMAINS` (ministère, ISRA,
   ANCAR, SAED, FAO, CIRAD, IFDC, AfricaRice…). Le texte est alors ajouté à la fiche avec son repère de source.
4. Une fiche modifiée de cette façon est protégée du rechargement du fichier du dépôt (`--force` pour l'écraser) ;
   `python manage.py export_agronomic_guides` réécrit le fichier du dépôt à partir de la base, pour le versionner.

## 18.4 Prévu, non implémenté

Recherche web pendant la conversation, pour combler les manques : à n'activer qu'avec un service de recherche restreint aux
domaines de confiance, des réponses marquées « non encore validées par l'équipe » et chaque résultat versé dans la file de
validation ci-dessus. Tant que ce n'est pas fait, l'assistant n'accède à aucune source en direct.
