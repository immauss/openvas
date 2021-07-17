#!/bin/bash
set -Eeuo pipefail
echo "install curl"

export DEBIAN_FRONTEND=noninteractive
export LANG=C.UTF-8

apt-get update
apt-get install -y gnupg curl

#echo "Install the postgres repo"
#echo "deb http://apt.postgresql.org/pub/repos/apt buster-pgdg main" > /etc/apt/sources.list.d/pgdg.list
#curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

apt-get update 
apt-get upgrade -y
echo "install required packages"
PACKAGES=$(cat package-list-buster)
apt-get install -yq --no-install-recommends $PACKAGES
/usr/sbin/update-ca-certificates --fresh
# ospd needs a newer version of python psutil than available in ubuntu
#/usr/bin/pip install psutil
python3 -m pip install psutil






