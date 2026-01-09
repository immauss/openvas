#!/usr/bin/env bash
set -euo pipefail

# Main operational data dir (current cluster lives here)
PGDATA="${PGDATA:-/data/database}"

# Derived paths
BASE_DIR="$(dirname "${PGDATA}")"
STAGING="${PGDATA}_15_new"      # temporary 15 data dir during upgrade
OLD_BAK="${PGDATA}_13_old"      # where we'll move the original 13 data
SENTINEL="${BASE_DIR}/.upgraded_pgdata_13_to_15"

echo "[pg-upgrade] Starting PGDATA upgrade helper (13 -> 15)"
echo "[pg-upgrade] PGDATA=${PGDATA}"
echo "[pg-upgrade] STAGING=${STAGING}"
echo "[pg-upgrade] OLD_BAK=${OLD_BAK}"
echo "[pg-upgrade] SENTINEL=${SENTINEL}"

# 1. Check current data dir
if [[ ! -d "${PGDATA}" ]]; then
  echo "[pg-upgrade] ${PGDATA} not found. Nothing to upgrade."
  exit 0
fi

if [[ ! -f "${PGDATA}/PG_VERSION" ]]; then
  echo "[pg-upgrade] ${PGDATA}/PG_VERSION missing. Not a valid PostgreSQL data dir. Aborting."
  exit 1
fi

CURVER="$(tr -d '[:space:]' < "${PGDATA}/PG_VERSION")"
echo "[pg-upgrade] Detected PG_VERSION=${CURVER} in ${PGDATA}"

# 2. If already on 15, we're done
if [[ "${CURVER}" == "15" ]]; then
  echo "[pg-upgrade] Cluster already at 15. Nothing to do."
  # Optionally touch sentinel if missing
  if [[ ! -f "${SENTINEL}" ]]; then
    touch "${SENTINEL}"
  fi
  exit 0
fi

# Only upgrade from 13
if [[ "${CURVER}" != "13" ]]; then
  echo "[pg-upgrade] PG_VERSION=${CURVER} is not 13. Skipping upgrade."
  exit 0
fi

# 3. Make sure old cluster is not running
if [[ -f "${PGDATA}/postmaster.pid" ]]; then
  OLDPID="$(head -n1 "${PGDATA}/postmaster.pid" || true)"
  if [[ -n "${OLDPID}" ]] && ps -p "${OLDPID}" >/dev/null 2>&1; then
    echo "[pg-upgrade] Stopping running 13 instance (PID=${OLDPID})..."
    sudo -u postgres /usr/lib/postgresql/13/bin/pg_ctl -D "${PGDATA}" -m fast stop || true
  else
    echo "[pg-upgrade] Stale postmaster.pid detected, removing..."
    rm -f "${PGDATA}/postmaster.pid"
  fi
fi

# 4. Prepare staging dir for 15
if [[ -d "${STAGING}" ]]; then
  echo "[pg-upgrade] Removing existing staging dir ${STAGING}..."
  rm -rf "${STAGING}"
fi

echo "[pg-upgrade] Initializing new PG 15 cluster in ${STAGING}..."
sudo -u postgres /usr/lib/postgresql/15/bin/initdb -D "${STAGING}" 

# 5. Run pg_upgrade (old: PGDATA, new: STAGING)
cd "${BASE_DIR}"

echo "[pg-upgrade] Running pg_upgrade (13 -> 15)..."
sudo -u postgres /usr/lib/postgresql/15/bin/pg_upgrade \
  -d "${PGDATA}" \
  -D "${STAGING}" \
  -b /usr/lib/postgresql/13/bin \
  -B /usr/lib/postgresql/15/bin

echo "[pg-upgrade] pg_upgrade completed successfully."

# Optional: analyze new cluster
if [[ -x "./analyze_new_cluster.sh" ]]; then
  echo "[pg-upgrade] Running analyze_new_cluster.sh (non-fatal on failure)..."
  sudo -u postgres ./analyze_new_cluster.sh || echo "[pg-upgrade] analyze_new_cluster.sh failed; continuing."
fi

# 6. Swap directories: move old 13 -> *_13_old, staging 15 -> live PGDATA
if [[ -d "${OLD_BAK}" ]]; then
  TS="$(date +%s)"
  echo "[pg-upgrade] Backup dir ${OLD_BAK} already exists, renaming to ${OLD_BAK}_${TS}..."
  mv "${OLD_BAK}" "${OLD_BAK}_${TS}"
fi

echo "[pg-upgrade] Moving old 13 cluster from ${PGDATA} to ${OLD_BAK}..."
mv "${PGDATA}" "${OLD_BAK}"

echo "[pg-upgrade] Moving new 15 cluster from ${STAGING} to ${PGDATA}..."
mv "${STAGING}" "${PGDATA}"

touch "${SENTINEL}"

echo "[pg-upgrade] Upgrade done."
echo "[pg-upgrade] Current cluster: ${PGDATA} (15)"
echo "[pg-upgrade] Backup of original 13 cluster: ${OLD_BAK}"
