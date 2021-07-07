#!/bin/bash
set -Eeuo pipefail
echo "install curl"

export DEBIAN_FRONTEND=noninteractive
export LANG=C.UTF-8

apt-get update
apt-get install -y gnupg curl

echo "Install the postgres repo"
echo "deb http://apt.postgresql.org/pub/repos/apt focal-pgdg main" > /etc/apt/sources.list.d/pgdg.list
curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

apt-get update 

echo "install required packages"
PACKAGES=$(cat package-list-running)
apt-get install -yq --no-install-recommends $PACKAGES
/usr/sbin/update-ca-certificates --fresh
# ospd needs a newer version of python psutil than available in ubuntu
#pip install psutil

echo "Install nodejs"
# Install Node.js
curl -sL https://deb.nodesource.com/setup_10.x | bash -
apt-get install nodejs -yq --no-install-recommends 

echo "Install yarn"
# Install Yarn
curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
apt-get update
apt-get install yarn -yq --no-install-recommends




