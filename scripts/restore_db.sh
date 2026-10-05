#!/usr/bin/env bash
# ==============================================================================
# Naatal Agro — Script de Restauration de la Base de Données
# Usage: ./scripts/restore_db.sh <chemin_vers_fichier_backup.gz>
# ==============================================================================
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage : $0 <fichier_backup.gz>"
    echo "Exemple : $0 ./database/backups/naatal_agro_pg_20261005_120000.sql.gz"
    exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "${BACKUP_FILE}" ]; then
    echo "❌ Fichier de sauvegarde introuvable : ${BACKUP_FILE}"
    exit 1
fi

echo "=== [Naatal Agro] Restauration depuis ${BACKUP_FILE} ==="

if [ -f "./backend/.env" ]; then
    export $(grep -v '^#' ./backend/.env | xargs -0 -n1 2>/dev/null || true)
fi

USE_POSTGRES="${USE_POSTGRES:-False}"

if [[ "${BACKUP_FILE}" == *"_pg_"* ]] || [ "${USE_POSTGRES}" = "True" ] || [ "${USE_POSTGRES}" = "true" ]; then
    DB_NAME="${DB_NAME:-naatal_agro_db}"
    DB_USER="${DB_USER:-postgres}"
    DB_HOST="${DB_HOST:-127.0.0.1}"
    DB_PORT="${DB_PORT:-5432}"

    echo "-> Restauration PostgreSQL vers ${DB_NAME}..."
    gunzip -c "${BACKUP_FILE}" | PGPASSWORD="${DB_PASSWORD:-}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}"
    echo "✓ Restauration PostgreSQL terminée."
else
    SQLITE_TARGET="./backend/db.sqlite3"
    echo "-> Restauration SQLite vers ${SQLITE_TARGET}..."
    gunzip -c "${BACKUP_FILE}" > "${SQLITE_TARGET}"
    echo "✓ Restauration SQLite terminée."
fi

echo "=== [Naatal Agro] Base de données restaurée avec succès ==="
