#!/bin/bash
set -Eeuo pipefail
# Source this for the latest release versions
. build.rc
apt update
echo "install required packages"
df -h
ls -l /tmp
PACKAGES=$(cat package-list-buster-build)
apt-get install -yq --no-install-recommends $PACKAGES


python3 -m pip install psutil
