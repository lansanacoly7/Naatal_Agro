# 15 — INTÉGRATION SONARQUBE & QUALITÉ DU CODE (NAATAL AGRO)

Ce document formalise la politique de qualité continue, d'analyse statique et de couverture de code pour le projet **Naatal Agro**.

---

## 1. Objectifs & Philosophie

Dans le cadre du projet de fin de formation et pour respecter les standards d'ingénierie d'une grande entreprise, la qualité du code n'est pas négociable.

SonarQube intervient comme **juge de paix automatisé** pour :
- **Détecter les bugs et failles de sécurité** avant la fusion des branches (`main`, `test`, `develop`).
- **Éliminer la dette technique** (complexité cyclomatique excessive, duplications, code mort).
- **Garantir une couverture de tests supérieure à 80 %** sur le backend et le mobile.
- **Empêcher toute régression** grâce aux seuils de la **Quality Gate**.

---

## 2. Cartographie de la Configuration

| Composant | Rôle | Emplacement |
| :--- | :--- | :--- |
| **Configuration SonarQube** | Paramètres du projet, sources, exclusions, chemins des rapports | [`sonar-project.properties`](file:///sonar-project.properties) |
| **Pipeline CI/CD** | Automatisation des tests, génération des rapports et déclenchement du scan | [`.github/workflows/ci.yml`](file:///.github/workflows/ci.yml) |
| **Serveur Local SonarQube** | Stack Docker (SonarQube Community + PostgreSQL) pour audit local | [`docker-compose.sonar.yml`](file:///docker-compose.sonar.yml) |
| **Rapport Couverture Backend** | Format Cobertura XML issu de `coverage.py` | `backend/coverage.xml` |
| **Rapport Couverture Mobile** | Format LCOV issu de `flutter test --coverage` | `mobile/coverage/lcov.info` |

---

## 3. Critères de la Quality Gate (Porte de Qualité)

Toute branche ou Pull Request doit impérativement satisfaire les seuils suivants :

| Indicateur | Seuil Exigé | Statut Actuel Naatal Agro |
| :--- | :--- | :--- |
| **Couverture de code (Backend)** | $\ge 80\,\%$ | **$88\,\%$** (59 tests unitaires passés) |
| **Couverture de code (Mobile)** | $\ge 80\,\%$ sur logique métier | **Actif** (11 tests unitaires/widgets passés) |
| **Bugs bloquants ou critiques** | **0** | **0** (`dart analyze lib` propre, `manage.py check` propre) |
| **Vulnérabilités de sécurité** | **0** | **0** (Vérifications auth/permissions DRF validées) |
| **Security Hotspots non revus** | **0** | **0** |
| **Ratio de dette technique** | $\le 5\,\%$ | Conforme |
| **Taux de duplication de code** | $\le 3\,\%$ | Conforme |

---

## 4. Guide d'Exécution Locale

### Étape 1 : Générer les rapports de couverture de tests

#### A. Backend Django
Depuis la racine du projet :
```bash
cd backend
.\venv\Scripts\coverage.exe run --source='apps' manage.py test
.\venv\Scripts\coverage.exe xml -o coverage.xml
.\venv\Scripts\coverage.exe report -m
```

#### B. Mobile Flutter
Depuis la racine du projet :
```bash
cd mobile
flutter test --coverage
```
Le fichier généré est automatiquement placé dans `mobile/coverage/lcov.info`.

---

### Étape 2 : Lancer SonarQube en local (Optionnel)

Pour exécuter une instance SonarQube complète sur votre machine locale via Docker :
```bash
docker compose -f docker-compose.sonar.yml up -d
```
1. Accédez à l'interface web : **http://localhost:9000**
2. Identifiants par défaut : `admin` / `admin` (changez le mot de passe au premier accès).
3. Créez un projet nommé `naatal-agro` avec la clé `naatal-agro`.
4. Générez un jeton d'analyse (*Project Token*).

---

### Étape 3 : Exécuter le SonarScanner en local

Si vous disposez de `sonar-scanner` installé sur votre poste :
```bash
sonar-scanner -Dsonar.host.url=http://localhost:9000 -Dsonar.token=<VOTRE_JETON>
```

Ou directement via l'image Docker officielle du scanner :
```bash
docker run --rm \
  --network host \
  -v "${PWD}:/usr/src" \
  sonarsource/sonar-scanner-cli \
  -Dsonar.host.url=http://localhost:9000 \
  -Dsonar.token=<VOTRE_JETON>
```

---

## 5. Automatisation dans GitHub Actions (CI)

Dans [`.github/workflows/ci.yml`](file:///.github/workflows/ci.yml) :
1. Le job `backend-test` exécute la suite de tests Django sous `coverage.py`, génère `coverage.xml` et le publie comme artefact CI.
2. Le job `flutter-test` exécute la suite sous `flutter test --coverage` et publie `mobile/coverage/lcov.info`.
3. Le job `sonarqube` télécharge ces deux rapports et déclenche l'analyse via l'action officielle `SonarSource/sonarqube-scan-action@v4`.

### Variables secrètes à configurer dans GitHub (Repository Settings > Secrets and variables > Actions) :
- `SONAR_TOKEN` : Jeton d'authentification généré dans SonarQube ou SonarCloud.
- `SONAR_HOST_URL` : URL de votre instance SonarQube (ou `https://sonarcloud.io` si utilisation du cloud gratuit pour les projets open-source).

---

## 6. Bonnes pratiques de développement au quotidien

1. **Aucun `try/catch` vide** : Toute exception doit être loggée (`logger.error(...)` côté Django, affichage utilisateur ou `debugPrint` côté Flutter).
2. **Typage strict** : Ne pas utiliser `dynamic` ou `Object` quand le type est prévisible.
3. **Séparation des responsabilités** : Aucune logique métier complexe dans les widgets Flutter ou dans les templates/URLs Django.
4. **Validations en amont** : Tout modèle de données externe doit passer par un sérialiseur ou un constructeur `fromJson` robuste.
