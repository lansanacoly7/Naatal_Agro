# 🤝 Plan de Collaboration & Répartition des Tâches — Naatal Agro
## Antigravity (DevOps / Tech Lead Exécution) & Claude (Architecte / Auditeur / Cadrage Soutenance)

> **Objectif** : Unir les forces complémentaires des deux agents pour livrer un projet agricole robuste, exempt de bugs bloquants, conforme aux 22 blocs d'évaluation et prêt à 100% pour la soutenance devant le jury ISEP.

---

## ⚖️ Analyse des Complémentarités : Points Forts & Points Faibles

| Agent | Points Forts 🌟 | Limites à cadrer ⚠️ | Rôle Idéal sur le Projet |
| :--- | :--- | :--- | :--- |
| **Antigravity** | • Exécution directe en environnement réel (terminal, compilation, migrations Django, `flutter test`, `dart analyze`, scripts Bash).<br>• Infrastructure, Docker, Nginx, configurations CI/CD et plomberie système.<br>• Développement de code actif et réactivité multi-fichiers. | • Risque de sur-automatiser ou de vouloir tout traiter d'un coup sans découpage.<br>• Tendance initiale à produire des évaluations trop optimistes sans recul terrain. | **Ingénieur Système, Intégrateur & Développeur Fullstack Exécutant** |
| **Claude** | • Rigueur d'audit clinique, détection fine des incohérences et des bugs métier subtils.<br>• Recul stratégique et protection du calendrier (soutenance à 3 semaines : évite les refactorings risqués).<br>• Rédaction académique, conformité juridique (Loi CDP Sénégal) et argumentaire de soutenance. | • Ne peut pas exécuter en continu des commandes lourdes (Docker Desktop éteint, exécution Flutter non systématique).<br>• Nécessite des tâches bien délimitées pour ne pas modifier les mêmes fichiers en parallèle. | **Architecte Logiciel, Auditeur Qualité & Coach de Soutenance** |

---

## 📋 Répartition Méthodique par Bloc (Les 22 Piliers)

### 🎨 1. Mobile & UI/UX ➔ **Attribué à Antigravity**
- [ ] **Tâche AGY-1.1** : Ajouter un indicateur visuel de statut de connectivité (Online / Mode Hors-ligne synchronisé) dans l'en-tête de l'application mobile.
- [ ] **Tâche AGY-1.2** : Généraliser le *Pull-to-Refresh* (`RefreshIndicator`) sur les écrans de liste (Mes Cultures, Cotations Marchés, Notifications).
- [ ] **Tâche AGY-1.3** : Sécuriser les états de chargement (shimmer/skeleton) et les affichages vides (*empty states*) sans fausses données.
- [ ] **Tâche AGY-1.4** : Maintenir `dart analyze lib` à 0 warning et tous les tests Flutter au vert.

---

### 📚 2. Contenus Pédagogiques & Fiches Agronomiques ➔ **Claude (Spécification) + Antigravity (Code)**
- [ ] **Tâche CLAUDE-2.1** : Rédiger le catalogue agronomique officiel pour les 5 cultures phares du Sénégal (Oignon des Niayes, Tomate industrielle de la Vallée, Arachide du Bassin arachidier, Mil, Riz irrigué) avec :
  - Cycles culturaux et calendriers de semis/récolte au Sénégal.
  - Besoins hydriques et règles de fertilisation (NPK / fumure organique).
  - Guide de lutte intégrée contre les bio-agresseurs locaux (Mineuse, Chenille légionnaire, Mildiou).
- [ ] **Tâche AGY-2.2** : Intégrer ce catalogue dans un modèle Django `AgronomicGuide` dans `apps.agriculture`, exposer l'endpoint REST `/api/agriculture/guides/` et brancher l'écran mobile de détail produit dessus.

---

### 👶 3. Protection des Mineurs, Données Personnelles (CDP Sénégal) & RGPD ➔ **Attribué à Claude**
- [ ] **Tâche CLAUDE-3.1** : Rédiger la Charte de Protection des Données Personnelles conforme à la **Loi n° 2008-12 du Sénégal** (Commission des Données Personnelles - CDP) :
  - Finalités agricoles exclusives du traitement.
  - Clause explicite sur les mineurs (< 18 ans : déclaration sous la responsabilité du tuteur de l'exploitation).
  - Procédure d'exercice du droit d'accès, de rectification et d'effacement (droit à l'oubli).
- [ ] **Tâche AGY-3.2** : Intégrer les champs de consentement sur le modèle `User` (`terms_accepted`, `privacy_accepted_at`) et l'endpoint de restitution de cette charte `/api/users/legal/`.

---

### 🎮 4. Gamification Agricole & Durabilité ➔ **Claude (Game Design) + Antigravity (Backend/Mobile)**
- [ ] **Tâche CLAUDE-4.1** : Définir le système de progression de l'exploitant (3 paliers : *Exploitant Novice*, *Producteur Confirmé*, *Maître Agro-Écologique*) et 4 badges concrets valorisables devant le jury :
  - 🏅 *Pionnier Naatal* (Compte configuré et première culture enregistrée).
  - 🛡️ *Sentinelle Sanitaire* (Signalement épidémiologique utile à la communauté).
  - 💧 *Gestion Raisonnée* (Activité d'irrigation économe consignée).
  - 📈 *Rigueur de Gestion* (Suivi financier complet d'une campagne).
- [ ] **Tâche AGY-4.2** : Coder les modèles `Badge` et `UserBadge` dans Django, l'endpoint `/api/users/gamification/` et l'affichage des badges sur le profil mobile.

---

### 👨‍🏫 5. Dashboard Formateur / Conseiller Agricole (Ex-Enseignant) ➔ **Claude & Antigravity**
- [ ] **Tâche CLAUDE-5.1** : Cadrer l'usage pour la formation ISEP : comment un formateur ou un conseiller agricole supervise une cohorte d'étudiants exploitants (suivi des parcelles d'application).
- [ ] **Tâche AGY-5.2** : Implémenter le rôle `advisor` dans l'API et l'endpoint de synthèse `/api/users/supervision/advisor/` (nombre de parcelles suivies, alertes actives, taux de saisie des activités).

---

### 👨‍👩‍👧 6. Dashboard Exploitation Familiale (Ex-Parent) ➔ **Antigravity**
- [ ] **Tâche AGY-6.1** : Implémenter le rôle `family_head` permettant à un chef de famille ou gérant de groupement de voir la vue consolidée des récoltes et des dépenses de l'exploitation.

---

### 🔐 7. Audit Sécurité, Secrets & Révocation ➔ **Attribué à l'Utilisateur + Claude**
- [ ] **Tâche UTILISATEUR-7.1** : Révoquer le token personnel GitHub dans les réglages GitHub.
- [ ] **Tâche UTILISATEUR-7.2** : Renseigner les vraies clés API (`API_KEY_GROQ`, `API_KEY_GEMINI`, `API_KEY_OPENWEATHER`) dans le fichier local `backend/.env`.
- [ ] **Tâche CLAUDE-7.3** : Vérifier la conformité de `.env.example` et valider qu'aucun nouveau secret n'est exposé.

---

### ⚙️ 8. Infrastructure, Docker, Backups & Monitoring ➔ **Attribué à Antigravity**
- [ ] **Tâche AGY-8.1** : Valider la construction des conteneurs via `docker compose build` et le lancement `docker compose up -d` dès que Docker Desktop est démarré.
- [ ] **Tâche AGY-8.2** : Tester le cycle de sauvegarde et restauration réelle (`scripts/backup_db.sh` et `scripts/restore_db.sh`).
- [ ] **Tâche AGY-8.3** : Valider le fonctionnement des sondes de santé `/api/health/` sous charge locale.

---

### 🎓 9. Rapport de Projet, Scénario de Démo & Soutenance ➔ **Attribué à Claude**
- [ ] **Tâche CLAUDE-9.1** : Rédiger le **Scénario de Démonstration 5 minutes Chrono** pour la soutenance (étapes exactes à dérouler sur le smartphone sans risquer un bug devant le jury).
- [ ] **Tâche CLAUDE-9.2** : Préparer la **Fiche Réponses aux Questions Pièges du Jury** :
  - Pourquoi avoir retiré le B2B ? (Argument : recentrage V1 sur la souveraineté alimentaire et les producteurs, B2B reporté en phase 3).
  - Pourquoi `dashboard_screen.dart` est-il volumineux ? (Argument : choix pragmatique de centralisation pour garantir zéro régression avant le diplôme, refactor modulaire planifié en V2).
  - Comment fonctionne l'IA sans fuite de données ? (Argument : RAG déterministe ORM cloisonné par utilisateur, exclusion stricte du Text-to-SQL direct).
- [ ] **Tâche CLAUDE-9.3** : Mettre à jour la section architecture et résultats dans le document de rapport final.

---

## 🔄 Règle d'Or de Non-Concurrence

Pour éviter que les deux agents n'entrent en conflit dans le même dépôt :
1. **Antigravity** opère principalement sur le code exécutable : `mobile/lib/`, scripts d'infrastructure, exécution des tests et commandes de compilation.
2. **Claude** opère sur la conception, les fiches agronomiques, les textes légaux CDP, la documentation académique et la préparation de soutenance.
3. Chaque agent lit ce fichier avant d'entamer une tâche et coche son avancement (`[x]`).
