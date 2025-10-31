# gvm_wait_feeds: wait until **no feeds are currently syncing** and status is **OK** (gvm-cli over TLS)
#
# Drop this function into your script, then call `gvm_wait_feeds ...`.
# Depends on: gvm-cli, xmllint (Debian: libxml2-utils)
#
# Success criteria (per your spec):
#   - Top-level /get_feeds_response/@status_text == "OK"
#   - **Zero** occurrences of /get_feeds_response/feed/currently_syncing
#   - (Versions may be absent while syncing; we do not rely on <version> for readiness.)
#
# Behavior:
#   - Polls until BOTH conditions are true → exit 0
#   - If timeout before they are true → exit 5 (non-zero)
#   - Any CLI/parsing error → non-zero
#
# Examples:
#   export GVM_HOST=127.0.0.1 GVM_PORT=9390 GVM_USERNAME=admin GVM_PASSWORD=admin
#   gvm_wait_feeds -i 10 -t 1800 -q
#
# Exit codes:
#   0 = status_text==OK and no feed has <currently_syncing>
#   2 = bad arguments
#   3 = required command missing
#   4 = gvm-cli query failed
#   5 = timeout (not ready within TIMEOUT)

gvm_wait_feeds() {
  # shellcheck disable=SC2034
  local PROG="gvm_wait_feeds"
  local HOST="${GVM_HOST:-127.0.0.1}"
  local PORT="${GVM_PORT:-9390}"
  local USER="${GVM_USERNAME:-admin}"
  local PASS="${GVM_PASSWORD:-admin}"
  local INTERVAL=10
  local TIMEOUT=1800
  local QUIET=0

  _gvmwf_usage() {
    cat <<USAGE
Usage: gvm_wait_feeds [options]
  -H, --host HOST         gvmd host (default: ${HOST})
  -p, --port PORT         gvmd port (default: ${PORT})
  -u, --user USER         GMP username (default: ${USER})
  -w, --password PASS     GMP password (default: from env)
  -i, --interval SECS     poll interval (default: ${INTERVAL})
  -t, --timeout SECS      overall timeout (default: ${TIMEOUT})
  -q, --quiet             less verbose output
  -h, --help              show this help
USAGE
  }

  _gvmwf_need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "${PROG}: missing required command: $1" >&2; return 3; }; }
  _gvmwf_log() { [ "$QUIET" -eq 1 ] || echo "$@"; }

  # Parse args
  while [ $# -gt 0 ]; do
    case "$1" in
      -H|--host) HOST="$2"; shift 2;;
      -p|--port) PORT="$2"; shift 2;;
      -u|--user) USER="$2"; shift 2;;
      -w|--password) PASS="$2"; shift 2;;
      -i|--interval) INTERVAL="$2"; shift 2;;
      -t|--timeout) TIMEOUT="$2"; shift 2;;
      -q|--quiet) QUIET=1; shift;;
      -h|--help) _gvmwf_usage; return 0;;
      *) echo "${PROG}: unknown option: $1" >&2; _gvmwf_usage >&2; return 2;;
    esac
  done

  _gvmwf_need_cmd gvm-cli || return 3
  _gvmwf_need_cmd xmllint || return 3

  # Build gvm-cli command with global opts, then connection type `tls`, then its opts
  # shellcheck disable=SC2206
  local GVM_CMD=( \
    su -c \
    "gvm-cli \
    --gmp-username "$USER" \
    --gmp-password "$PASS" \
    tls \
    --hostname "$HOST" \
    --port "$PORT" \
    -X '<get_feeds/>'" gvm
  )

  local start_ts end_ts now
  start_ts=$(date +%s)
  end_ts=$((start_ts + TIMEOUT))

  # Pretty-print a feed row (type, name, version if present, syncing timestamp if present)
  _gvmwf_row() {
    # $1: XML, $2: 1-based index — use /get_feeds_response/feed
    local xml="$1" idx="$2" type name version syncing ts
    type=$(printf '%s' "$xml" | xmllint --xpath "normalize-space((/get_feeds_response/feed)[$idx]/type/text())" - 2>/dev/null || true)
    name=$(printf '%s' "$xml" | xmllint --xpath "normalize-space((/get_feeds_response/feed)[$idx]/name/text())" - 2>/dev/null || true)
    version=$(printf '%s' "$xml" | xmllint --xpath "normalize-space((/get_feeds_response/feed)[$idx]/version/text())" - 2>/dev/null || true)
    syncing=$(printf '%s' "$xml" | xmllint --xpath "string(count((/get_feeds_response/feed)[$idx]/currently_syncing))" - 2>/dev/null || echo 0)
    ts=$(printf '%s' "$xml" | xmllint --xpath "normalize-space((/get_feeds_response/feed)[$idx]/currently_syncing/timestamp/text())" - 2>/dev/null || true)
    if [ "$syncing" = "0" ]; then
      printf "%-10s %-30s version=%s
" "${type:-?}" "${name:-?}" "${version:-?}"
    else
      printf "%-10s %-30s SYNCING ts=%s
" "${type:-?}" "${name:-?}" "${ts:-?}"
    fi
  }

  # Compute counts: total feeds and how many are currently syncing
  _gvmwf_counts() {
    # $1: XML → echo "syncing total status_text"
    local xml="$1" total syncing status_text
    total=$(printf '%s' "$xml" | xmllint --xpath 'string(count(/get_feeds_response/feed))' - 2>/dev/null || echo 0)
    syncing=$(printf '%s' "$xml" | xmllint --xpath 'string(count(/get_feeds_response/feed[currently_syncing]))' - 2>/dev/null || echo 0)
    status_text=$(printf '%s' "$xml" | xmllint --xpath 'string(/get_feeds_response/@status_text)' - 2>/dev/null || true)
    echo "$syncing $total $status_text"
  }

  while :; do
    local XML_OUT
    if ! XML_OUT=$("${GVM_CMD[@]}" 2>/dev/null); then
      echo "${PROG}: failed to query gvmd via gvm-cli" >&2
      return 4
    fi

    local counts syncing total status_text
    counts=$(_gvmwf_counts "$XML_OUT") || counts="0 0 "
    syncing=${counts%% *}
    total=${counts#* }
    total=${total%% *}
    status_text=${counts#* * }

    _gvmwf_log "Feeds syncing: ${syncing}/${total} | status_text: ${status_text:-?}"

    if [ "$total" != "0" ] && [ "$syncing" = "0" ] && [ "$status_text" = "OK" ]; then
      _gvmwf_log "Feeds are ready: no currently_syncing and status OK."
      if [ "$QUIET" -ne 1 ]; then
        local i
        for i in $(seq 1 "$total"); do _gvmwf_row "$XML_OUT" "$i"; done
      fi
      return 0
    fi

    now=$(date +%s)
    remaining=$(( $end_ts - $now ))
    if [ "$now" -ge "$end_ts" ]; then
      echo "${PROG}: timeout waiting for feeds to finish syncing (timeout=${TIMEOUT}s)" >&2
      local i
      for i in $(seq 1 "$total"); do _gvmwf_row "$XML_OUT" "$i"; done
      return 5
    fi

    if [ "$QUIET" -ne 1 ]; then
      local i
      for i in $(seq 1 "$total"); do _gvmwf_row "$XML_OUT" "$i"; done
      echo "--- sleeping ${INTERVAL}s ${remaining}s remaining before timeout ---"
    fi
    sleep "$INTERVAL"
  done
}
