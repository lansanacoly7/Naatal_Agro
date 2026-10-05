#!/usr/bin/env bash
# ==============================================================================
# Naatal Agro — Script de vérification et préparation de pré-déploiement
# ==============================================================================
set -e

echo "=== [Naatal Agro] Préparation du déploiement ==="

cd backend
source venv/bin/activate || source venv/Scripts/activate

# 1. Vérification système Django
echo "-> Vérification système en environnement de production..."
python manage.py check --deploy --settings=core.settings.prod

# 2. Exécution des migrations
echo "-> Application des migrations en attente..."
python manage.py migrate --noinput --settings=core.settings.prod

# 3. Collecte des fichiers statiques
echo "-> Collecte des fichiers statiques..."
python manage.py collectstatic --noinput --settings=core.settings.prod

cd ..

echo "=== [Naatal Agro] Déploiement prêt ! ==="
