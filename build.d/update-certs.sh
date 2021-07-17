#/bin/bash
set -Eeuo pipefail
echo "Starting Build..." 
echo "Updating ssl certs .."
# Needed for the arm/v7 for some reason
/usr/sbin/update-ca-certificates --fresh
