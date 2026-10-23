# Recette de Naatal IA — critères de réussite du §10

**Référentiel :** [`Naatal_IA.md`](../Naatal_IA.md), section 10
**Date de la recette :** 23 octobre 2026
**Remplace** la version du 21 octobre 2026 (« GO PRODUCTION, 99/100 »), retirée : elle affirmait des fonctions qui n'existaient pas ou n'avaient pas été éprouvées (synthèse vocale serveur gTTS, wolof « validé », « 0 simulation »), sur la foi de 104 tests.

> **Lecture honnête.** Ce document ne donne ni note ni « homologation ». Il dit, critère par critère, ce que les tests
> démontrent, ce qu'ils ne démontrent pas, et ce qui reste à faire. Aucune des preuves ci-dessous ne remplace un essai sur
> téléphone réel avec de vrais producteurs.

## 1. Résultats mesurés

| Contrôle | Résultat | Commande |
|---|---|---|
| Tests backend (tout le projet) | **641 réussis**, 1 ignoré | `python manage.py test` |
| Dont recette du §10 | **32 réussis** | `python manage.py test apps.ai_assistant.test_acceptance_section10` |
| Migrations en attente | aucune | `python manage.py makemigrations --check --dry-run` |
| Analyse statique mobile | 0 problème | `flutter analyze lib` |
| Tests mobile | **170 réussis** | `flutter test` |
| Français / wolof (corpus de l'équipe) | langue 100 %, demande comprise 100 % (31 phrases) ; variantes SMS 100 % (12) | `python manage.py evaluate_languages` |

Les tests de recette tournent **sans clé d'IA** : ils prouvent ce que le code impose autour du modèle (données, validations,
garde-fous, messages d'échec), pas la qualité des réponses d'un modèle réel.

## 2. Critère par critère

Statuts : **Démontré** (test automatique), **Partiel** (une partie seulement), **Non vérifié** (rien ne le prouve encore).

| # | Critère du §10 | Statut | Preuve (tests `test_acceptance_section10.py`) | Limite connue |
|---|---|---|---|---|
| 1 | Répond à une question simple sans long texte | **Partiel** | `C01` : consigne « 2 à 5 phrases » et plafond de 700 jetons envoyés au modèle ; « vite » → 350 ; les questions chiffrées sont répondues en moins de 14 lignes sans appeler le modèle | La longueur réellement produite par chaque modèle n'est pas mesurée |
| 2 | Approfondit une analyse complexe | **Démontré** | `C02` : explication des hausses de dépenses par catégorie ; « en détail » → 1000 jetons ; suivi « Et le mois dernier ? » | — |
| 3 | Consulte les bonnes données du compte | **Démontré** | `C03` : seuls les chiffres du compte connecté apparaissent | — |
| 4 | Calcule correctement recettes, dépenses, résultat | **Démontré** | `C04` : 20 000 / 4 000 / 16 000 FCFA exacts (calcul par le code, jamais par le modèle) | Résultat = recettes − dépenses *saisies* |
| 5 | Distingue recettes et bénéfice réel | **Démontré** | `C05` : « Résultat estimé… ce n'est pas un bénéfice » ; une culture sans vente n'est pas présentée comme une perte | Pas de bénéfice réel : stock, matériel et dépenses non saisies ne sont pas comptés |
| 6 | Ne révèle jamais les données d'un autre utilisateur | **Démontré** (réponses et prompt) | `C06` : stock, bilan, rappels, mouvements, prompt envoyé au modèle, confirmation d'une proposition d'autrui refusée | Fuites par le modèle lui-même non testables sans modèle réel |
| 7 | Demande des précisions si ambigu | **Démontré** | `C07` : demande incomplète → question, rien d'écrit ; produit ambigu → liste de candidats | Verbes et formulations non prévus → pas de question |
| 8 | Exécute seulement après validation | **Démontré** | `C08` : rien d'écrit avant confirmation ; un seul enregistrement malgré un double appui ; annulation = rien | — |
| 9 | Confirme seulement après un résultat positif | **Démontré** | `C09` : vente supérieure au stock refusée, aucun succès annoncé ; un texte de modèle qui prétend avoir écrit est corrigé | Détection par motifs (français et wolof) : un tour de phrase inédit peut passer |
| 10 | Crée et consulte les alertes | **Démontré** (serveur) | `C10` : création après confirmation, consultation | Sonnerie du téléphone : configuration native non vérifiée sur appareil ; la PWA ne sonne pas onglet fermé |
| 11 | Gère erreurs réseau et pannes d'IA | **Démontré** (serveur) | `C11` : panne totale, limite quotidienne, texte inexploitable écarté ; les chiffres restent disponibles | Comportement du téléphone en connexion très faible non testé |
| 12 | Recommandations avec hypothèses et limites | **Partiel** | `C12` : avertissements ⚠️/ℹ️ présents dans les comparaisons et stocks ; données absentes nommées | Les conseils rédigés par le modèle n'ont pas de contrôle formel de leurs hypothèses |
| 13 | Français et wolof dans les limites vérifiées | **Partiel** | `C13` + `docs/evaluation_langues.md` : détection et compréhension des demandes sur 43 phrases écrites par l'équipe ; confirmation identique en wolof ; langue conservée | **Corpus non relu par un locuteur natif.** Wolof généré : lisible parfois, qualité inconnue ; réponses chiffrées et confirmations en français |
| 14 | Échange vocal utilisable et compréhensible | **Partiel / non vérifié sur appareil** | `C14` : transcription → circuit normal → confirmation ; plus de synthèse serveur | Micro et lecture jamais essayés sur téléphone (pas d'appareil) ; Whisper ne gère pas officiellement le wolof ; pas de voix wolof sur le téléphone |
| 15 | Maintenable, testable, sécurisé, coût raisonnable | **Partiel** | `C15` : journal d'usage sans contenu ; injection via un enregistrement neutralisée ; points d'accès protégés ; plafond quotidien et budget de temps | Coût réel par utilisateur non mesuré en production ; relecture sécurité externe non faite |

## 3. Ce qui n'a PAS été vérifié

1. **Appareil réel** : micro, lecture vocale, sonneries de rappel, graphiques (aucun JDK, émulateur ni téléphone sur la machine).
2. **Wolof** : aucun locuteur natif n'a relu le corpus ni les réponses. Les motifs de détection d'« écriture prétendue » en wolof sont à valider.
3. **Qualité des modèles** : un essai en direct a révélé un brouillon interne laissé par Gemini et une boucle de répétitions chez Groq (désormais écartés) ; la qualité moyenne n'est pas mesurée sur un grand échantillon.
4. **Charge et coût** : pas de test de montée en charge ; le coût par utilisateur dépend des quotas des fournisseurs.
5. **Connexion faible** : le comportement hors ligne de l'assistant n'a pas été testé de bout en bout.

## 4. Corrections apportées à l'ancien dossier

| Affirmation de l'ancien dossier | Réalité |
|---|---|
| « STRICT GO PRODUCTION, 99/100 » | Pas de note : voir le tableau ci-dessus |
| « Aucun composant simulé ne subsiste » | Faux au moment de l'écriture ; la recette ne dit que ce qui est testé |
| Synthèse vocale `gTTS` sur `/api/ai/voice/synthesize/` | Supprimée : la lecture se fait sur le téléphone (`flutter_tts`) |
| Wolof « VALIDÉ » (lexique de quelques mots) | Détection et compréhension mesurées sur un corpus d'équipe ; qualité de génération non validée |
| « 104 tests Django, 103 Flutter » | 641 et 170 à ce jour |
| Rate limit « 60/h » comme sécurité | Un plafond quotidien par utilisateur et un budget de temps s'y ajoutent ; le coût réel reste à mesurer |
