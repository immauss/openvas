#!/usr/bin/env bash
# Create a GVMD target + task ("Full and fast"), create SSH credentials and assign to the target,
# then start the scan using gvm-cli (GMP over TLS) with the "OpenVAS Default" scanner.
#
# Requirements: gvm-cli, xmllint (libxml2-utils)
# Env (or override with flags): GVM_HOST, GVM_PORT, GVM_USERNAME, GVM_PASSWORD
# Hosts to scan: slack rocky debian suse ubuntu
#
# Usage example:
#   export GVM_HOST=127.0.0.1 GVM_PORT=9390 GVM_USERNAME=admin GVM_PASSWORD=admin
#   ./create-and-scan-gmp.sh -n "Hosts Scan - Full and fast"
#
set -euo pipefail

HOST=${GVM_HOST:-127.0.0.1}
PORT=${GVM_PORT:-9390}
USER=${GVM_USERNAME:-admin}
PASS=${GVM_PASSWORD:-admin}
TASK_NAME="Hosts Scan - Full and fast"
TARGET_NAME="Hosts Scan - Target"
HOSTS=(slack rocky debian suse ubuntu)
QUIET=0

# SSH credential values requested
CRED_NAME="scannable-ssh"
CRED_LOGIN="scannable"
CRED_PASSWORD="Passw0rd"

usage(){
  cat <<USAGE
Usage: $0 [options]
  -H HOST     gvmd host (default: $HOST)
  -p PORT     gvmd port (default: $PORT)
  -u USER     GMP username (default: $USER)
  -w PASS     GMP password (default: from env)
  -n NAME     task base name (default: "$TASK_NAME")
  -q          quiet
  -h          help
USAGE
}

while getopts ":H:p:u:w:n:qh" opt; do
  case "$opt" in
    H) HOST="$OPTARG";;
    p) PORT="$OPTARG";;
    u) USER="$OPTARG";;
    w) PASS="$OPTARG";;
    n) TASK_NAME="$OPTARG"; TARGET_NAME="$OPTARG Target";;
    q) QUIET=1;;
    h) usage; exit 0;;
    :) echo "Option -$OPTARG requires an argument" >&2; exit 2;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage; exit 2;;
  esac
done

need(){ command -v "$1" >/dev/null 2>&1 || { echo "Missing command: $1" >&2; exit 3; }; }
need gvm-cli; need xmllint;

log(){ [ "$QUIET" -eq 1 ] || echo "$@"; }
run_gmp(){
  gvm-cli \
    --gmp-username "$USER" \
    --gmp-password "$PASS" \
    tls \
    --hostname "$HOST" \
    --port "$PORT" \
    -X "$1"
}

first_or_empty(){ xmllint --xpath "string(($1)[1])" - 2>/dev/null || true; }

# 1) Resolve scan config id for name "Full and fast"
log "Resolving scan config id for 'Full and fast'..."
SC_XML=$(run_gmp '<get_configs/>' || true)
SCAN_CONFIG_ID=$(printf '%s' "$SC_XML" | first_or_empty '(/get_configs_response/config[name="Full and fast"]/@id)')
if [ -z "$SCAN_CONFIG_ID" ]; then
  SCAN_CONFIG_ID=$(printf '%s' "$SC_XML" | first_or_empty '(/get_configs_response/config/@id)')
fi
[ -n "$SCAN_CONFIG_ID" ] || { echo "Failed to resolve scan config id" >&2; exit 4; }
log "Using scan config id: $SCAN_CONFIG_ID"

# 2) Resolve a port list id (prefer All IANA assigned TCP)
log "Resolving port list id..."
PL_XML=$(run_gmp '<get_port_lists/>' || true)
PORT_LIST_ID=$(printf '%s' "$PL_XML" | first_or_empty '(/get_port_lists_response/port_list[name="All IANA assigned TCP"]/@id)')
[ -n "$PORT_LIST_ID" ] || PORT_LIST_ID=$(printf '%s' "$PL_XML" | first_or_empty '(/get_port_lists_response/port_list/@id)')
[ -n "$PORT_LIST_ID" ] || { echo "Failed to resolve port list id" >&2; exit 4; }
log "Using port list id: $PORT_LIST_ID"

# 3) Resolve the 'OpenVAS Default' scanner id
log "Resolving scanner id for 'OpenVAS Default'..."
SCN_XML=$(run_gmp '<get_scanners/>' || true)
SCANNER_ID=$(printf '%s' "$SCN_XML" | first_or_empty '(/get_scanners_response/scanner[name="OpenVAS Default"]/@id)')
[ -n "$SCANNER_ID" ] || { echo "Failed to find scanner 'OpenVAS Default'" >&2; exit 4; }
log "Using scanner id: $SCANNER_ID"

# 4) Create or reuse SSH credential (username+password)
log "Ensuring SSH credential '$CRED_NAME'..."
CRED_XML=$(run_gmp '<get_credentials/>' || true)
CRED_ID=$(printf '%s' "$CRED_XML" | first_or_empty '(/get_credentials_response/credential[name="'"$CRED_NAME"'"]/@id)')
if [ -z "$CRED_ID" ]; then
  CREATE_CRED="<create_credential><name>${CRED_NAME}</name><type>up</type><login>${CRED_LOGIN}</login><password>${CRED_PASSWORD}</password></create_credential>"
  CREATE_CRED_RESP=$(run_gmp "$CREATE_CRED")
  CRED_ID=$(printf '%s' "$CREATE_CRED_RESP" | first_or_empty '(/create_credential_response/@id)')
fi
[ -n "$CRED_ID" ] || { echo "Failed to create/resolve credential" >&2; exit 4; }
log "Credential id: $CRED_ID"

# 5) Ensure/lookup target by name
log "Ensuring target '$TARGET_NAME'..."
TGT_XML=$(run_gmp "<get_targets filter=\"name=${TARGET_NAME}\"/>" || true)
TARGET_ID=$(printf '%s' "$TGT_XML" | first_or_empty '(/get_targets_response/target/@id)')
if [ -z "$TARGET_ID" ]; then
  HOSTS_CSV=$(printf '%s' "${HOSTS[*]}" | tr ' ' ',')
  CREATE_TGT="<create_target><name>${TARGET_NAME}</name><hosts>${HOSTS_CSV}</hosts><port_list id=\"${PORT_LIST_ID}\"/><ssh_credential id=\"${CRED_ID}\"/></create_target>"
  CT_RESP=$(run_gmp "$CREATE_TGT")
  TARGET_ID=$(printf '%s' "$CT_RESP" | first_or_empty '(/create_target_response/@id)')
fi
[ -n "$TARGET_ID" ] || { echo "Failed to create/resolve target" >&2; exit 4; }
log "Target id: $TARGET_ID"

# 6) Ensure/lookup task by name, use OpenVAS Default scanner explicitly
log "Ensuring task '$TASK_NAME' with OpenVAS Default scanner..."
TASKS_XML=$(run_gmp "<get_tasks filter=\"name=${TASK_NAME}\"/>" || true)
TASK_ID=$(printf '%s' "$TASKS_XML" | first_or_empty '(/get_tasks_response/task/@id)')
if [ -z "$TASK_ID" ]; then
  CREATE_TASK="<create_task><name>${TASK_NAME}</name><config id=\"${SCAN_CONFIG_ID}\"/><target id=\"${TARGET_ID}\"/><scanner id=\"${SCANNER_ID}\"/></create_task>"
  CTK_RESP=$(run_gmp "$CREATE_TASK")
  TASK_ID=$(printf '%s' "$CTK_RESP" | first_or_empty '(/create_task_response/@id)')
fi
[ -n "$TASK_ID" ] || { echo "Failed to create/resolve task" >&2; exit 4; }
log "Task id: $TASK_ID"

# 7) Start the task
log "Starting task..."
START_XML=$(run_gmp "<start_task task_id=\"${TASK_ID}\"/>")
REPORT_ID=$(printf '%s' "$START_XML" | first_or_empty '(/start_task_response/report_id/text())')
log "Started. Report id: ${REPORT_ID:-<pending>}"

echo "Task ${TASK_NAME} started (task id: ${TASK_ID}). Report id: ${REPORT_ID:-<pending>}"
