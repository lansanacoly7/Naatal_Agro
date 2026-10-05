#!/usr/bin/env bash
# ==============================================================================
# Naatal Agro — Script de Sauvegarde Automatique de la Base de Données
# Supporte PostgreSQL et SQLite avec compression GZIP et politique de rétention
# ==============================================================================
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-./database/backups}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RETENTION_DAYS="${RETENTION_DAYS:-7}"

mkdir -p "${BACKUP_DIR}"

echo "=== [Naatal Agro] Démarrage de la sauvegarde BDD (${TIMESTAMP}) ==="

# Chargement optionnel des variables d'environnement
if [ -f "./backend/.env" ]; then
    export $(grep -v '^#' ./backend/.env | xargs -0 -n1 2>/dev/null || true)
fi

USE_POSTGRES="${USE_POSTGRES:-False}"

if [ "${USE_POSTGRES}" = "True" ] || [ "${USE_POSTGRES}" = "true" ] || [ "${USE_POSTGRES}" = "1" ]; then
    DB_NAME="${DB_NAME:-naatal_agro_db}"
    DB_USER="${DB_USER:-postgres}"
    DB_HOST="${DB_HOST:-127.0.0.1}"
    DB_PORT="${DB_PORT:-5432}"
    BACKUP_FILE="${BACKUP_DIR}/naatal_agro_pg_${TIMESTAMP}.sql.gz"

    echo "-> Sauvegarde PostgreSQL : ${DB_NAME} sur ${DB_HOST}:${DB_PORT}..."
    PGPASSWORD="${DB_PASSWORD:-}" pg_dump -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" --clean --if-exists | gzip > "${BACKUP_FILE}"
    echo "✓ Sauvegarde PostgreSQL terminée : ${BACKUP_FILE} ($(du -h "${BACKUP_FILE}" | cut -f1))"
else
    SQLITE_FILE="./backend/db.sqlite3"
    BACKUP_FILE="${BACKUP_DIR}/naatal_agro_sqlite_${TIMESTAMP}.db.gz"

    if [ -f "${SQLITE_FILE}" ]; then
        echo "-> Sauvegarde SQLite : ${SQLITE_FILE}..."
        gzip -c "${SQLITE_FILE}" > "${BACKUP_FILE}"
        echo "✓ Sauvegarde SQLite terminée : ${BACKUP_FILE} ($(du -h "${BACKUP_FILE}" | cut -f1))"
    else
        echo "⚠️ Fichier SQLite ${SQLITE_FILE} introuvable."
    fi
fi

# Rétention : suppression des sauvegardes de plus de N jours
echo "-> Application de la politique de rétention (${RETENTION_DAYS} jours)..."
find "${BACKUP_DIR}" -name "naatal_agro_*.gz" -type f -mtime "+${RETENTION_DAYS}" -exec rm -f {} + 2>/dev/null || true

echo "=== [Naatal Agro] Sauvegarde terminée avec succès ==="
