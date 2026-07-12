#!/usr/bin/env bash
set -euo pipefail

OLD_VERSION=$(/home/scott/Projects/openvas/bin/get-old-tag.sh)
NEW_VERSION="$1"

DOCKER_BIN="${DOCKER_BIN:-docker}"
IMAGE="${IMAGE:-immauss/openvas}"

# OpenVAS persistent data path inside your container.
DATA_PATH="${DATA_PATH:-/data}"

# How long the old container should run to initialize/create the DB.
OLD_INIT_SECONDS="${OLD_INIT_SECONDS:-1800}"

# How long the new container must stay running to be considered successful.
# 900 seconds = 15 minutes.
TEST_SECONDS="${TEST_SECONDS:-600}"

# Poll interval while watching containers.
POLL_SECONDS="${POLL_SECONDS:-10}"

# Keep failed test volume/container around for inspection.
KEEP_ON_FAIL="${KEEP_ON_FAIL:-1}"

TEST_ID="migration-test-$(date -u +%s)"
VOLUME_NAME="${VOLUME_NAME:-${TEST_ID}-data}"
OLD_CONTAINER="${TEST_ID}-old"
NEW_CONTAINER="${TEST_ID}-new"
wait_for_gsa() {
  local port="8080"  
  local host="127.0.0.1"
  local interval="15"
  local container="$1"
  local url="http://${host}:${port}/"
  command -v curl >/dev/null 2>&1 || { echo "curl not found"; return 2; }

  echo "Waiting for GSA HTTP response at ${url} (poll every ${interval}s)..."
  while true ; do
    # silent, follow redirects, 5s connect+transfer timeout, capture HTTP status code
    http_code=$(curl -sS -L --connect-timeout 5 --max-time 5 -o /dev/null -w "%{http_code}" "${url}" 2>/dev/null || echo "")
    if [[ -n "$http_code" ]]; then
      if [[ "$http_code" -ge 200 && "$http_code" -lt 400 ]]; then
        echo "GSA responded with HTTP ${http_code}"
        return 0
      else
        echo "Received HTTP ${http_code}; waiting ${interval}s..."
      fi
    else
      echo "No HTTP response; waiting ${interval}s..."
    fi
    sleep "${interval}"
    if ! is_running $container; then
        echo "$container is no longer running"
        docker logs --tail 20 $container
        exit 
    fi


  done
}


cleanup_success() {
    echo "Cleaning up successful test resources..."
    "$DOCKER_BIN" rm -f "$OLD_CONTAINER" "$NEW_CONTAINER" >/dev/null 2>&1 || true
    "$DOCKER_BIN" volume rm "$VOLUME_NAME" >/dev/null 2>&1 || true
    "$DOCKER_BIN" image rm "immauss/openvas:$OLD_VERSION" || true
}

fail() {
    echo
    echo "NO-GO: $*" >&2
    echo

    echo "Old container logs:"
    "$DOCKER_BIN" logs --tail 120 "$OLD_CONTAINER" 2>/dev/null || true

    echo
    echo "New container logs:"
    "$DOCKER_BIN" logs --tail 200 "$NEW_CONTAINER" 2>/dev/null || true

    if [ "$KEEP_ON_FAIL" = "1" ]; then
        echo
        echo "Keeping failed test resources for inspection:"
        echo "  Volume:        $VOLUME_NAME"
        echo "  Old container: $OLD_CONTAINER"
        echo "  New container: $NEW_CONTAINER"
    else
        "$DOCKER_BIN" rm -f "$OLD_CONTAINER" "$NEW_CONTAINER" >/dev/null 2>&1 || true
        "$DOCKER_BIN" volume rm "$VOLUME_NAME" >/dev/null 2>&1 || true
    fi

    exit 1
}

is_running() {
    local container="$1"

    [ "$("$DOCKER_BIN" inspect -f '{{.State.Running}}' "$container" 2>/dev/null || echo false)" = "true" ]
}

container_health() {
    local container="$1"

    "$DOCKER_BIN" inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container" 2>/dev/null || echo "missing"
}

wait_for_old_container() {
    local deadline
    local health

    deadline=$(( $(date +%s) + OLD_INIT_SECONDS ))

    echo "Waiting up to ${OLD_INIT_SECONDS}s for old container initialization..."

    while [ "$(date +%s)" -lt "$deadline" ]; do
        if ! is_running "$OLD_CONTAINER"; then
            fail "Old container stopped before initialization completed."
        fi

        health="$(container_health "$OLD_CONTAINER")"

        case "$health" in
            healthy)
                echo "Old container is healthy."
                #return 0
                ;;
            unhealthy)
                fail "Old container became unhealthy."
                ;;
            none)
                # No HEALTHCHECK exists; fall back to time-based initialization.
                ;;
        esac

        sleep "$POLL_SECONDS"
    done

    if ! is_running "$OLD_CONTAINER"; then
        fail "Old container was not running after initialization wait."
    fi

    echo "Old container ran for ${OLD_INIT_SECONDS}s; proceeding with upgrade test."
}

watch_new_container() {
    local deadline
    local remaining
    local status
    wait_for_gsa $NEW_CONTAINER
    deadline=$(( $(date +%s) + TEST_SECONDS ))

    echo "Watching new container for ${TEST_SECONDS}s..."

    while [ "$(date +%s)" -lt "$deadline" ]; do
        if ! is_running "$NEW_CONTAINER"; then
            status="$("$DOCKER_BIN" inspect -f '{{.State.Status}} exit={{.State.ExitCode}} error={{.State.Error}}' "$NEW_CONTAINER" 2>/dev/null || true)"
            fail "New container stopped before the success window completed. Status: ${status}"
        fi

        remaining=$(( deadline - $(date +%s) ))
        echo "New container still running; ${remaining}s remaining..."
        sleep "$POLL_SECONDS"
    done
}

echo "Upgrade migration test"
echo "  Image:       $IMAGE"
echo "  Old version: $OLD_VERSION"
echo "  New version: $NEW_VERSION"
echo "  Volume:      $VOLUME_NAME"
echo "  Data path:   $DATA_PATH"
echo

echo "Creating disposable test volume..."
"$DOCKER_BIN" volume create "$VOLUME_NAME" >/dev/null

echo "Starting old container: ${IMAGE}:${OLD_VERSION}"
"$DOCKER_BIN" run -d \
    --name "$OLD_CONTAINER" \
    --restart no \
    -v "${VOLUME_NAME}:${DATA_PATH}" \
    -e SKIPSYNC="true" \
    -e PGVER="13" \
    -p 8080:9392 \
    "${IMAGE}:${OLD_VERSION}"

wait_for_gsa $OLD_CONTAINER

echo "Stopping old container cleanly..."
"$DOCKER_BIN" stop -t 120 "$OLD_CONTAINER" >/dev/null || fail "Failed to stop old container cleanly."
DEADLINE=10
COUNT=0
while is_running "$OLD_CONTAINER"; do
    echo "$OLD_CONTAINER still running"
    sleep 10
    COUNT=$(($COUNT + 1))
    if [ $COUNT -eq $DEADLINE ]; then
        echo "$OLD_CONTAINER took too long. Bailing out."
    fi
done

echo "Starting new container: ${IMAGE}:${NEW_VERSION}"
"$DOCKER_BIN" run -d \
    --name "$NEW_CONTAINER" \
    --restart no \
    -v "${VOLUME_NAME}:${DATA_PATH}" \
    -e SKIPSYNC="true" \
    -p 8080:9392 \
    "${IMAGE}:${NEW_VERSION}"

watch_new_container

echo
echo "GO: ${IMAGE}:${NEW_VERSION} stayed running for ${TEST_SECONDS}s after upgrading from ${IMAGE}:${OLD_VERSION}."

cleanup_success
