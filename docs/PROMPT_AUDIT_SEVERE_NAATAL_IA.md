# MISSION D'AUDIT TECHNIQUE ET SÉCURITÉ INDÉPENDANT : NAATAL IA

Tu agis ici en tant qu'**Auditeur Technique Principal, Architecte Logiciel Senior et Auditeur de Sécurité Indépendant** (niveau SonarQube Enterprise / Tech Due Diligence Big Tech / ISO 25010).

Ta mission est de réaliser un **AUDIT TECHNIQUE IMPLACABLE, IMPARTIAL ET SANS COMPLAISANCE** de tout le travail réalisé jusqu'ici sur le module **Naatal IA** (l'assistant intelligent de Naatal Agro), en confrontant le code source réel aux spécifications du fichier `Naatal_IA.md` et aux règles de conduite de `.agents/antigravity_behaviour.md`.

---

## DIRECTIVE ABSOLUE : "TRUST NOTHING, VERIFY EVERYTHING"
- Tu as interdiction formelle de croire les affirmations ou rapports précédents.
- Ne suppose JAMAIS qu'une fonctionnalité existe ou fonctionne parce qu'une méthode existe ou qu'un test est au vert.
- Tout ce qui n'est pas vérifié dans le code source réel (fichiers backend et frontend) est considéré comme non fait ou simulé.
- Traque impitoyablement les illusions d'avancement, les mocks cachés, les blocs `catch (_) {}` silencieux, le code mort, les fallbacks trompeurs et les écarts par rapport au cahier des charges.

---

## 1. PÉRIMÈTRE TECHNIQUE À EXAMINER LIGNE PAR LIGNE

Tu dois lire et inspecter directement dans le workspace les fichiers suivants :

1. **Spécification de référence** :
   - `Naatal_IA.md` (Notamment sections 2, 4.A, 4.B, 4.C, 4.D, 5, 6, 7, 8, 9 et 10).
2. **Backend Django REST Framework** :
   - `backend/apps/ai_assistant/models.py`
   - `backend/apps/ai_assistant/views.py`
   - `backend/apps/ai_assistant/services.py`
   - `backend/apps/ai_assistant/actions.py`
   - `backend/apps/ai_assistant/knowledge.py`
   - `backend/apps/ai_assistant/voice.py`
   - `backend/apps/ai_assistant/serializers.py`
   - Tous les fichiers de tests `backend/apps/ai_assistant/test_*.py`
3. **Frontend Flutter Mobile** :
   - `mobile/lib/features/ai/data/ai_provider.dart`
   - `mobile/lib/features/ai/data/models/ai_message.dart`
   - `mobile/lib/screens/assistant/assistant_screen.dart`
   - `mobile/test/ai_conversation_model_test.dart`

---

## 2. GRILLE D'ANALYSE DÉTAILLÉE (CRITÈRES D'AUDIT SÉVÈRES)

Pour chacune des 10 phases et chacun des critères de réussite de `Naatal_IA.md`, tu dois répondre avec des preuves techniques concrètes :

### A. Phase 1 — Fondations & Gestion des Conversations
- Le modèle de données `AIConversation` isole-t-il réellement les données entre utilisateurs ? Y a-t-il un risque d'injection ou de fuite IDOR / multi-tenant ?
- Le frontend restaure-t-il fidèlement la session ou y a-t-il des états incohérents (mélange d'anciennes questions orphelines, pertes de contexte au rechargement) ?
- Les erreurs d'API (`PATCH`, `DELETE`) sont-elles gérées avec un vrai feedback utilisateur ou masquées par des `catch (_)` vides ?

### B. Phase 2 — Moteur Conversationnel & Grounding
- Le système de failover (Groq <-> Gemini) est-il réel ou simulé ? Que se passe-t-il exactement si les deux clés API échouent ?
- La distinction entre source certifiée ISRA (`database`) et conseil général (`general`) est-elle inviolable ou peut-elle être contournée ?

### C. Phases 3 & 4 — Connexion aux Données Métier & Calculs Déterministes
- `get_farmer_context` : Quelles données sont réellement transmises au modèle ? Y a-t-il des troncatures brutales (`[:5]`, `[:10]`) qui font perdre la réalité du bilan de l'agriculteur ?
- Les calculs financiers et de stocks sont-ils réellement déterministes ?
- Respectent-ils l'exigence de la section 4.B : comparaison entre périodes (ex: ce mois-ci vs le mois dernier), distinction marge / chiffre d'affaires / trésorerie ?

### D. Phase 5 — Actions Métier Sécurisées (Function Calling)
- Comment fonctionne la détection d'intention dans `actions.py` ? Est-ce un système robuste ou de simples regex fragiles qui cassent dès que l'agriculteur formule sa phrase différemment ?
- Le cycle de validation en 2 étapes (`pending_confirmation` -> confirmation explicite) protège-t-il réellement contre les doubles soumissions ou les écritures non désirées ?
- L'écriture en base est-elle atomique (`transaction.atomic`) ?

### E. Phase 6 — Alertes & Programmation de Rappels
- Comment est gérée la date/heure d'un rappel (ex: « Rappelle-moi demain à 7h ») ? Est-ce réellement planifié pour plus tard, ou créé instantanément parce qu'il n'y a aucun planificateur de tâches asynchrone (Celery/CRON) ?

### F. Phase 7 — Français et Wolof
- Le traitement du wolof est-il une vraie compréhension multilingue ou juste quelques mots-clés hardcodés dans des expressions régulières ?
- Que se passe-t-il si l'agriculteur parle un wolof plus nuancé ?

### G. Phase 8 — Interaction Vocale (STT & TTS)
- **Transcription (STT)** : Le widget mobile enregistre-t-il vraiment le flux microphone du téléphone en direct, ou est-ce seulement une boîte de dialogue avec des boutons textes ?
- **Synthèse Vocale (TTS)** : L'assistant vocal sait-il lire ses réponses à haute voix comme exigé au point 5 de `Naatal_IA.md` (*« 5. La synthèse vocale de cette réponse. 6. La lecture audio avec possibilité d'interrompre la réponse »*) ? Où est le code TTS ?

### H. Phase 9 — Interface Utilisateur & Mobile UX
- L'interface mobile respecte-t-elle l'identité visuelle Naatal Agro (`#1B5E20`) ?
- Affiche-t-elle des graphiques ou tableaux quand les chiffres l'exigent (section 6 de `Naatal_IA.md`) ou seulement du texte brut ?

### I. Phase 10 — Qualité des Tests & Résilience
- Les tests unitaires sont-ils de véritables tests de cas limites et de sécurité, ou de simples tests cosmétiques qui ne vérifient pas les vrais scénarios d'échec ?
- Y a-t-il des failles de sécurité, des risques de dépassement de quota (rate limiting) ou des fuites de secrets ?

---

## 3. FORMAT DE LIVRABLE EXIGÉ

Fournis un rapport structuré comprenant :
1. **Synthèse exécutive** : Note globale sur 100 de maturité de production et avis d'admissibilité (GO / NO-GO).
2. **Matrice de conformité Phase par Phase (1 à 10)** : Tableau avec % réel d'avancement, écarts constatés par rapport à `Naatal_IA.md`.
3. **Registre des Anomalies et Faiblesses** classées par sévérité :
   - 🔴 **CRITICAL** (bloquant, mensonge technique, fonctionnalité essentielle manquante ou simulée).
   - 🟠 **MAJOR** (incomplet, vulnérabilité, manque de robustesse sur le terrain).
   - 🟡 **MINOR** (dette technique, code perfectible, manque de test spécifique).
4. **Liste des faux-semblants identifiés** (ce qui a été présenté comme "fait/fini" alors que le code montre le contraire).
5. **Plan de redressement priorisé étape par étape** pour rendre Naatal IA 100% conforme et réellement prêt pour la production.
