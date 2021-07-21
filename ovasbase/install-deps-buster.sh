#!/bin/bash
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
export LANG=C.UTF-8

echo "Updating packages"
apt-get update 
apt-get upgrade -y
echo "install required packages"
PACKAGES=$(cat package-list-buster)
apt-get install -yq --no-install-recommends $PACKAGES
/usr/sbin/update-ca-certificates --fresh
#Clean up after apt
rm -rf /var/lib/apt/lists/*






