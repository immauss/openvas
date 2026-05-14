#!/usr/bin/env bash
echo "Starting script" 
set -euo pipefail

# --------------------------------------------------------------------
# setup-gvm-healthcheck-user.sh
#
# Creates/maintains a least-privilege GVM/GVMD user for container
# health checks over the gvmd Unix socket.
# --------------------------------------------------------------------
echo "Variable setup" 
GVMD_SOCKET="${GVMD_SOCKET:-/run/gvmd/gvmd.sock}"

GVM_ADMIN_USER="${GVM_ADMIN_USER:-admin}"
GVM_ADMIN_PASS="$1"
: "${GVM_ADMIN_PASS:?GVM_ADMIN_PASS is required}"

GVM_HEALTH_USER="${GVM_HEALTH_USER:-healthcheck}"
GVM_HEALTH_ROLE="${GVM_HEALTH_ROLE:-Healthcheck}"
GVM_HEALTH_PASS_FILE="${GVM_HEALTH_PASS_FILE:-/etc/gvm/healthcheck.pass}"

GVM_LOCAL_USER="${GVM_LOCAL_USER:-gvm}"
GVM_LOCAL_GROUP="${GVM_LOCAL_GROUP:-gvm}"

GVM_HEALTH_SETUP_RETRIES="${GVM_HEALTH_SETUP_RETRIES:-60}"
GVM_HEALTH_SETUP_SLEEP="${GVM_HEALTH_SETUP_SLEEP:-5}"

ADMIN_CFG=""
HEALTH_CFG=""
echo "Setup some functions" 

cleanup() {
  [ -n "${ADMIN_CFG:-}" ] && [ -f "$ADMIN_CFG" ] && rm -f "$ADMIN_CFG"
  [ -n "${HEALTH_CFG:-}" ] && [ -f "$HEALTH_CFG" ] && rm -f "$HEALTH_CFG"
}
trap cleanup EXIT

xml_escape() {
  sed \
    -e 's/&/\&amp;/g' \
    -e 's/</\&lt;/g' \
    -e 's/>/\&gt;/g' \
    -e 's/"/\&quot;/g' \
    -e "s/'/\&apos;/g"
}

make_gvm_cli_auth_config() {
  local user="$1"
  local pass="$2"
  local cfg="$3"

  {
    printf '[Auth]\n'
    printf 'gmp_username=%s\n' "$user"
    printf 'gmp_password=%s\n' "$pass"
  } > "$cfg"

  chmod 0600 "$cfg"
}

random_password_19() {
  local pw

  while :; do
    pw="$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 19 || true)"
    if [ "${#pw}" -eq 19 ]; then
      printf '%s' "$pw"
      return 0
    fi
  done
}

write_health_password_file() {
  local pass="$1"
  local tmpfile

  tmpfile="$(mktemp)"

  printf '%s\n' "$pass" > "$tmpfile"
  chown "$GVM_LOCAL_USER:$GVM_LOCAL_GROUP" "$tmpfile"
  chmod 0600 "$tmpfile"
  mv "$tmpfile" "$GVM_HEALTH_PASS_FILE"

  chown "$GVM_LOCAL_USER:$GVM_LOCAL_GROUP" "$GVM_HEALTH_PASS_FILE"
  chmod 0600 "$GVM_HEALTH_PASS_FILE"
}

gmp_admin() {
  local xml="$1"

  gvm-cli \
    --config "$ADMIN_CFG" \
    socket \
    --socketpath "$GVMD_SOCKET" \
    --xml "$xml"
}

gmp_health() {
  local pass="$1"
  local xml="$2"

  HEALTH_CFG="$(mktemp)"
  make_gvm_cli_auth_config "$GVM_HEALTH_USER" "$pass" "$HEALTH_CFG"

  gvm-cli \
    --config "$HEALTH_CFG" \
    socket \
    --socketpath "$GVMD_SOCKET" \
    --xml "$xml" gvm

  rm -f "$HEALTH_CFG"
  HEALTH_CFG=""
}

extract_response_id() {
  sed -n 's/.* id="\([^"]*\)".*/\1/p' | head -n 1
}

extract_named_object_id() {
  local object="$1"
  local name="$2"

  tr '\n' ' ' \
    | sed "s#</${object}>#</${object}>\n#g" \
    | awk -v object="$object" -v name="$name" '
        index($0, "<" object " id=\"") && index($0, "<name>" name "</name>") {
          if (match($0, "<" object " id=\"[^\"]+\"")) {
            id = substr($0, RSTART, RLENGTH)
            sub(/^.*id="/, "", id)
            sub(/"$/, "", id)
            print id
            exit
          }
        }
      '
}

get_role_id() {
  gmp_admin "<get_roles/>" | extract_named_object_id "role" "$GVM_HEALTH_ROLE"
}

get_user_id() {
  gmp_admin "<get_users/>" | extract_named_object_id "user" "$GVM_HEALTH_USER"
}

wait_for_gvmd_socket() {
  local i

  for i in $(seq 1 "$GVM_HEALTH_SETUP_RETRIES"); do
    if [ -S "$GVMD_SOCKET" ]; then
      return 0
    fi
    sleep "$GVM_HEALTH_SETUP_SLEEP"
  done

  echo "ERROR: gvmd socket not found: $GVMD_SOCKET" >&2
  return 1
}

wait_for_gvmd_gmp() {
  local i
  echo "Starting to wait for gmp"
  for i in $(seq 1 "$GVM_HEALTH_SETUP_RETRIES"); do
    echo "Loop iteration $i for $GVM_HEALTH_SETUP_RETRIES"
    gmp_admin '<get_version/>'
    if gmp_admin '<get_version/>' 2>/dev/null | grep -q '<get_version_response status="200"'; then
      return 0
    fi
    sleep "$GVM_HEALTH_SETUP_SLEEP"
  done

  echo "ERROR: gvmd did not respond to GMP get_version over socket: $GVMD_SOCKET" >&2
  return 1
}

health_password_works() {
  local pass="$1"

  [ -n "$pass" ] || return 1

  gmp_health "$pass" '<get_version/>' 2>/dev/null \
    | grep -q '<get_version_response status="200"'
}

ensure_role() {
  local role_id
  local role_name_xml

  role_id="$(get_role_id || true)"

  if [ -z "$role_id" ]; then
    role_name_xml="$(printf '%s' "$GVM_HEALTH_ROLE" | xml_escape)"

    role_id="$(
      gmp_admin "<create_role><name>${role_name_xml}</name><comment>Minimal role for container health checks</comment></create_role>" \
        | extract_response_id
    )"

    if [ -z "$role_id" ]; then
      echo "ERROR: Failed to create GVM role: $GVM_HEALTH_ROLE" >&2
      return 1
    fi

    echo "Created GVM role: $GVM_HEALTH_ROLE ($role_id)"
  else
    echo "GVM role already exists: $GVM_HEALTH_ROLE ($role_id)"
  fi

  # Keep this idempotent. Duplicate permission creation will fail harmlessly.
  for perm in authenticate get_version; do
    gmp_admin "<create_permission><name>${perm}</name><subject id=\"${role_id}\"><type>role</type></subject></create_permission>" >/dev/null 2>&1 || true
  done

  printf '%s\n' "$role_id"
}

ensure_user() {
  local role_id="$1"
  local user_id
  local existing_pass=""
  local new_pass
  local user_name_xml

  user_id="$(get_user_id || true)"

  if [ -s "$GVM_HEALTH_PASS_FILE" ]; then
    existing_pass="$(cat "$GVM_HEALTH_PASS_FILE")"
  fi

  if [ -n "$user_id" ]; then
    echo "GVM user already exists: $GVM_HEALTH_USER ($user_id)"

    if health_password_works "$existing_pass"; then
      echo "Existing password file works for GVM healthcheck user."
      write_health_password_file "$existing_pass"
      return 0
    fi

    echo "Existing password file missing or invalid. Setting a new password for $GVM_HEALTH_USER."

    new_pass="$(random_password_19)"
    gmp_admin "<modify_user user_id=\"${user_id}\"><password>${new_pass}</password><role id=\"${role_id}\"/></modify_user>" >/dev/null

    write_health_password_file "$new_pass"

    if ! health_password_works "$new_pass"; then
      echo "ERROR: New password did not work for existing GVM healthcheck user." >&2
      return 1
    fi

    return 0
  fi

  echo "GVM user does not exist. Creating: $GVM_HEALTH_USER"

  new_pass="$(random_password_19)"
  user_name_xml="$(printf '%s' "$GVM_HEALTH_USER" | xml_escape)"

  gmp_admin "<create_user><name>${user_name_xml}</name><password>${new_pass}</password><role id=\"${role_id}\"/></create_user>" >/dev/null

  write_health_password_file "$new_pass"

  if ! health_password_works "$new_pass"; then
    echo "ERROR: Password did not work for newly created GVM healthcheck user." >&2
    return 1
  fi
}

# --------------------------------------------------------------------
# Main
# --------------------------------------------------------------------
echo "Waiting for GVMD Socket"
wait_for_gvmd_socket

echo "Creating gvm auth config"
ADMIN_CFG="$(mktemp)"
make_gvm_cli_auth_config "$GVM_ADMIN_USER" "$GVM_ADMIN_PASS" "$ADMIN_CFG"

echo "Waiting for GMP" 
wait_for_gvmd_gmp

echo "Checking for healthcheck user"
ROLE_ID="$(ensure_role | tail -n 1)"
ensure_user "$ROLE_ID"
ls -l /$GVM_HEALTH_PASS_FILE
echo "Set owner/permissions of password file"
chown "$GVM_LOCAL_USER:$GVM_LOCAL_GROUP" "$GVM_HEALTH_PASS_FILE"
chmod 0600 "$GVM_HEALTH_PASS_FILE"

echo "GVM healthcheck user is ready."
echo "Password file: $GVM_HEALTH_PASS_FILE"