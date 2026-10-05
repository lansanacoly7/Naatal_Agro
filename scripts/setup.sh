#!/usr/bin/env bash
# ==============================================================================
# Naatal Agro — Script d'installation et de configuration de l'environnement
# ==============================================================================
set -e

echo "=== [Naatal Agro] Initialisation de l'environnement ==="

# 1. Configuration du backend Django
echo "-> Configuration du backend..."
cd backend
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi

source venv/bin/activate || source venv/Scripts/activate
pip install --upgrade pip
pip install -r requirements.txt

# Application des migrations
echo "-> Application des migrations de base de données..."
python manage.py migrate

cd ..

# 2. Configuration du mobile Flutter
echo "-> Récupération des dépendances Flutter..."
cd mobile
flutter pub get
cd ..

echo "=== [Naatal Agro] Environnement prêt avec succès ! ==="
