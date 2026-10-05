# 🤖 Module IA — Naatal Agro Engine

Ce répertoire héberge la configuration, les prompts de référence et les spécifications d'orchestration pour le moteur d'intelligence artificielle décisionnelle de Naatal Agro.

## Modèles Utilisés
1. **Groq (Llama-3.1-8b-instant)** : Moteur Text-to-SQL à faible latence et raisonnement analytique rapide sur les cotations et la rentabilité.
2. **Google Gemini (gemini-1.5-flash)** : Diagnostic visuel multimodal (maladies des feuilles, ravageurs, carences) et fallback d'analyse agronomique.

## Prompts de Référence
- `prompts/farming_advice.txt` : Directives agronomiques contextualisées aux sols, climats et calendriers culturaux du Sénégal.
- `prompts/disease_detection.txt` : Guide d'identification phytosanitaire et préconisations de traitements locaux (naturels et conventionnels).
- `prompts/market_prediction.txt` : Analyse prédictive des tendances de prix et aide à la décision de vente/stockage.
