#!/bin/bash
set -Eeuo pipefail
echo "install curl"

export DEBIAN_FRONTEND=noninteractive
export LANG=C.UTF-8

apt-get update
apt-get install -y gnupg curl wget apt-utils

echo "Install the postgres repo"
echo "deb http://apt.postgresql.org/pub/repos/apt bullseye-pgdg main" > /etc/apt/sources.list.d/pgdg.list
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

apt-get update 
apt-get upgrade -y
echo "install required packages"
PACKAGES=$(cat /scripts/package-list)
apt-get install -yq --no-install-recommends $PACKAGES
/usr/sbin/update-ca-certificates --fresh

# Now install latest nodejs & yarn ..
export NODE_VERSION=node_18.x
export KEYRING=/usr/share/keyrings/nodesource.gpg
export DISTRIBUTION="bullseye"

# the NodeJS apt source
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor |  tee "$KEYRING" >/dev/null
gpg --no-default-keyring --keyring "$KEYRING" --list-keys
echo "deb [signed-by=$KEYRING] https://deb.nodesource.com/$NODE_VERSION $DISTRIBUTION main" |  tee /etc/apt/sources.list.d/nodesource.list
echo "deb-src [signed-by=$KEYRING] https://deb.nodesource.com/$NODE_VERSION $DISTRIBUTION main" |  tee -a /etc/apt/sources.list.d/nodesource.list
# add the yarn apt source
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg |  apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" |  tee /etc/apt/sources.list.d/yarn.list

 apt update
 apt install -y nodejs yarn

#Clean up after apt
rm -rf /var/lib/apt/lists/*






