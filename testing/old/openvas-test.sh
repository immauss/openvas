#!/bin/bash

# Path to the docker-compose file in the "compose" folder
# This compose should also have one or two of the scannable images running.
COMPOSE_FILE_PATH="compose/docker-compose.yaml"

# GVM Credentials
GVM_USER="admin"
GVM_PASS="admin"

# Target settings for the scan
TARGET_NAME="Scannable Target"
TARGET_IP="scannable"  # Or the subnet of the docker containers. (Can we extract this from docker?)
SCAN_NAME="Test Scan"
SCAN_CONFIG="daba56c8-73ec-11df-a475-002264764cea"  # Full and fast config ID

# Helper function to wait for GVM readiness
wait_for_gvm() {
  echo "Waiting for GVM to initialize..."
  for i in {1..30}; do
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:9392 | grep -q "200"; then
      echo "GVM is up and running."
      return 0
    fi
    sleep 10
  done
  echo "GVM did not start in time."
  return 1
}

# Start Docker containers
start_containers() {
  echo "Starting Docker containers..."
  docker-compose -f $COMPOSE_FILE_PATH up -d
  if [ $? -ne 0 ]; then
    echo "Failed to start containers."
    exit 1
  fi
}

# Create a target using gvm-tools
create_target() {
  echo "Creating a target in GVM..."
  gvm-cli tls --hostname localhost --port 9390 --gmp-username $GVM_USER --gmp-password $GVM_PASS << EOF
<create_target>
  <name>$TARGET_NAME</name>
  <hosts>$TARGET_IP</hosts>
</create_target>
EOF
}

# Create and execute a scan using gvm-tools
create_and_run_scan() {
  echo "Creating and executing a scan..."
  gvm-cli tls --hostname localhost --port 9390 --gmp-username $GVM_USER --gmp-password $GVM_PASS << EOF
<create_task>
  <name>$SCAN_NAME</name>
  <comment>Automated test scan</comment>
  <config id="$SCAN_CONFIG"/>
  <target id="$(gvm-cli tls --hostname localhost --port 9390 --gmp-username $GVM_USER --gmp-password $GVM_PASS --xml '<get_targets/>' | grep -oP '(?<=id=")[^"]+')"/>
</create_task>
EOF

  echo "Launching scan..."
  gvm-cli tls --hostname localhost --port 9390 --gmp-username $GVM_USER --gmp-password $GVM_PASS << EOF
<start_task>
  <task id="$(gvm-cli tls --hostname localhost --port 9390 --gmp-username $GVM_USER --gmp-password $GVM_PASS --xml '<get_tasks/>' | grep -oP '(?<=id=")[^"]+')"/>
</start_task>
EOF
}

# Clean up Docker containers
cleanup() {
  echo "Cleaning up Docker containers..."
  docker-compose -f $COMPOSE_FILE_PATH down
}

# Main script execution
trap cleanup EXIT
start_containers
if wait_for_gvm; then
  create_target
  create_and_run_scan
else
  echo "Exiting due to GVM initialization failure."
fi
