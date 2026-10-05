#!/usr/bin/env bash
# ==============================================================================
# Naatal Agro — Script de peuplement des données de test (Seed)
# ==============================================================================
set -e

echo "=== [Naatal Agro] Amorçage des données de test ==="

cd backend
source venv/bin/activate || source venv/Scripts/activate

# 1. Peuplement des utilisateurs, cultures, marchés et cotations
echo "-> Exécution du seed initial..."
python seed.py

# 2. Peuplement du catalogue officiel de produits
echo "-> Peuplement du catalogue de produits agricoles..."
python populate_products.py

echo "=== [Naatal Agro] Données de test amorcées avec succès ! ==="
