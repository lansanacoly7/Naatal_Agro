#!/usr/bin/env bash
# ==============================================================================
# Naatal Agro — Peuplement des données de démonstration (DÉVELOPPEMENT UNIQUEMENT)
# Efface les données de démonstration existantes : refuse en production, demande une confirmation.
# Usage : ./scripts/seed.sh [--yes]
# ==============================================================================
set -euo pipefail

echo "=== [Naatal Agro] Amorçage des données de test ==="

cd backend
source venv/bin/activate || source venv/Scripts/activate

# Chaque script appelle core.safety : refus hors développement, confirmation obligatoire (sauf --yes)
echo "-> Exécution du seed initial..."
python seed.py "$@"

echo "-> Peuplement du catalogue de produits agricoles..."
python populate_products.py "$@"

echo "=== [Naatal Agro] Données de test amorcées avec succès ! ==="
