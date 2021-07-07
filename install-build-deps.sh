#!/bin/bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive
export LANG=C.UTF-8

PACKAGES=$(cat package-list-building)
apt-get install -yq --no-install-recommends $PACKAGES
/usr/sbin/update-ca-certificates --fresh

pip install psutil
