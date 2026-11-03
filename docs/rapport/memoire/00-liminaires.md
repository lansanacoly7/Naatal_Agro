# Dédicace

[À COMPLÉTER : dédicace personnelle (facultative).]

# Remerciements

Au terme de ce travail, nous tenons à exprimer notre reconnaissance à toutes les personnes qui, de près ou de loin, ont contribué à sa réalisation.

Nous remercions d'abord [À COMPLÉTER : nom et titre de l'encadrant pédagogique], qui a encadré ce projet, pour ses conseils, sa disponibilité et l'exigence qu'il a apportée à ce travail.

Nous remercions [À COMPLÉTER : nom et titre de l'encadrant professionnel, le cas échéant] pour [À COMPLÉTER : nature de l'accompagnement].

Nos remerciements vont également à l'ensemble de l'équipe pédagogique et administrative de l'Institut Supérieur d'Enseignement Professionnel (ISEP) [À COMPLÉTER : site ou campus], pour la qualité de la formation reçue.

Nous exprimons notre gratitude à [À COMPLÉTER : producteurs, conseillers agricoles, ou autres personnes consultées pendant le projet], pour le temps qu'ils nous ont accordé.

Nous remercions enfin nos familles et nos proches pour leur soutien constant tout au long de la formation.

# Résumé

L'agriculture occupe une place centrale dans l'économie et dans la vie quotidienne du Sénégal, mais le producteur prend encore la plupart de ses décisions (semer, traiter, vendre) sans accès commode à une information fiable, locale et à jour. Ce mémoire présente la conception, la réalisation et l'évaluation de **Naatal Agro**, une application mobile d'aide à la décision destinée aux producteurs sénégalais, dont une grande partie est peu lettrée.

L'application, développée avec Flutter (Android, iOS et application web progressive) et adossée à une interface de programmation Django REST Framework, réunit le suivi des cultures, la gestion des ventes, des dépenses et des stocks, un calendrier agricole par zone, la météo locale, une carte des marchés avec itinéraire, et un assistant conversationnel, **Naatal IA**, utilisable à la voix. L'assistant répond d'abord à partir de fiches agronomiques sourcées, signale ce qui manque au lieu de l'inventer, et n'écrit dans l'exploitation de l'utilisateur qu'après une confirmation explicite. L'interface est pensée pour les utilisateurs peu lettrés : images avant le texte, mots simples, lecture à voix haute, grandes zones tactiles.

La qualité du produit est établie par des preuves et non par des affirmations : 768 tests automatisés côté serveur et 245 côté mobile, passés avec succès le 30 octobre 2026, une intégration continue, des tests d'isolation des comptes, une mesure du nombre de requêtes et un audit technique de fin de projet. Cet audit a aussi mis en évidence des points à corriger avant une mise en production, présentés sans détour. Les résultats confirment la fiabilité de la chaîne de réponse de l'assistant et l'étanchéité des comptes ; l'adéquation du produit aux besoins réels des producteurs reste à valider sur le terrain.

**Mots-clés :** agriculture numérique, aide à la décision, assistant conversationnel, génération augmentée par la recherche, inclusion numérique, Sénégal, Flutter, Django.

# Abstract

Agriculture is central to Senegal's economy and daily life, yet farmers still make most of their decisions (when to sow, how to treat a crop, when and where to sell) without convenient access to reliable, local and up-to-date information. This thesis presents the design, implementation and evaluation of **Naatal Agro**, a decision-support mobile application for Senegalese farmers, many of whom have limited literacy.

Built with Flutter (Android, iOS and progressive web app) on top of a Django REST Framework API, the application brings together crop tracking, sales, expenses and stock management, a zone-based agricultural calendar, local weather, a market map with routing, and a conversational assistant, **Naatal IA**, that can be used by voice. The assistant answers primarily from sourced agronomic guides, states what it does not know instead of guessing, and writes to the user's farm records only after explicit confirmation. The interface is designed for low-literacy users: images before text, plain words, read-aloud, large touch targets.

Product quality is established by evidence rather than claims: 768 automated server-side tests and 245 mobile tests passed on 30 October 2026, continuous integration, account-isolation tests, query-count measurement and an end-of-project technical audit. The audit also identified issues to fix before any production release, which are reported openly. The results confirm the reliability of the assistant's answer pipeline and the isolation of user accounts; the fit of the product to farmers' real needs remains to be validated in the field.

**Keywords:** digital agriculture, decision support, conversational assistant, retrieval-augmented generation, digital inclusion, Senegal, Flutter, Django.

# Liste des sigles et abréviations

| Sigle | Signification |
|---|---|
| ANACIM | Agence nationale de l'aviation civile et de la météorologie |
| ANCAR | Agence nationale de conseil agricole et rural |
| ANSD | Agence nationale de la statistique et de la démographie |
| API | Interface de programmation (*Application Programming Interface*) |
| ARTP | Autorité de régulation des télécommunications et des postes |
| CDH | Centre pour le développement de l'horticulture |
| CDP | Commission de protection des données personnelles |
| CI/CD | Intégration et déploiement continus |
| DRF | Django REST Framework |
| FAO | Organisation des Nations unies pour l'alimentation et l'agriculture |
| IDOR | Référence directe non sécurisée à un objet (*Insecure Direct Object Reference*) |
| ISEP | Institut Supérieur d'Enseignement Professionnel |
| ISRA | Institut sénégalais de recherches agricoles |
| JWT | Jeton web signé (*JSON Web Token*) |
| LLM | Grand modèle de langage (*Large Language Model*) |
| OSRM | Moteur d'itinéraires libre (*Open Source Routing Machine*) |
| OTP | Code à usage unique (*One-Time Password*) |
| PFF | Projet de fin de formation |
| PWA | Application web progressive (*Progressive Web App*) |
| RAG | Génération augmentée par la recherche (*Retrieval-Augmented Generation*) |
| SAED | Société nationale d'aménagement et d'exploitation des terres du delta |
| TTS | Synthèse vocale (*Text-To-Speech*) |
| UML | Langage de modélisation unifié (*Unified Modeling Language*) |

<!--LISTES-->
