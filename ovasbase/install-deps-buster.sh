#!/bin/bash
set -Eeuo pipefail
echo "install curl"

export DEBIAN_FRONTEND=noninteractive
export LANG=C.UTF-8

apt-get update
apt-get install -y gnupg curl wget

echo "Install the postgres repo"
echo "deb http://apt.postgresql.org/pub/repos/apt buster-pgdg main" > /etc/apt/sources.list.d/pgdg.list
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

apt-get update 
apt-get upgrade -y
echo "install required packages"
PACKAGES=$(cat package-list-buster)
apt-get install -yq --no-install-recommends $PACKAGES
/usr/sbin/update-ca-certificates --fresh
#Clean up after apt
rm -rf /var/lib/apt/lists/*
# Filesystem setup for gvmd & openvas
#*#*#*# This can move to image creation #*#*#*#
if [ ! -d "/run/redis" ]; then
	mkdir /run/redis
	chmod 777 /run/redis
fi

echo "Adding gvm user"
mkdir -p /usr/local/share/gvm
useradd --home-dir /usr/local/share/gvm gvm
chown gvm:gvm -R /usr/local/share/gvm

mkdir -p /run/gvm
mkdir -p /run/ospd
chmod 770 /run/gvm /run/ospd
chgrp gvm /run/gvm /run/ospd







