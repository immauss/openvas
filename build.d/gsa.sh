#!/bin/bash
echo  "Procs $(nproc)" > /usr/local/include/BuildProcs
INSTALL_PREFIX="/usr/local/"
set -Eeuo pipefail
# Source this for the latest release versions
. build.rc
echo "Building gsa"  
cd /build
GSA_VERSION=$(echo $gsa| sed "s/^v\(.*$\)/\1/")
curl -f -L https://github.com/greenbone/gsa/archive/refs/tags/v$GSA_VERSION.tar.gz -o $gsa.tar.gz

tar -xf $gsa.tar.gz
<<<<<<< HEAD
#apt remove nodejs yarn -y 
ls -l
cd /build/*/
#export NODE_VERSION=node_16.x
#export KEYRING=/usr/share/keyrings/nodesource.gpg
#export DISTRIBUTION="bullseye"

#curl -fsSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor |  tee "$KEYRING" >/dev/null
#gpg --no-default-keyring --keyring "$KEYRING" --list-keys
#echo "deb [signed-by=$KEYRING] https://deb.nodesource.com/$NODE_VERSION $DISTRIBUTION main" |  tee /etc/apt/sources.list.d/nodesource.list
#echo "deb-src [signed-by=$KEYRING] https://deb.nodesource.com/$NODE_VERSION $DISTRIBUTION main" |  tee -a /etc/apt/sources.list.d/nodesource.list


 #apt update
 #apt install -y nodejs

#curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg |  apt-key add -
#echo "deb https://dl.yarnpkg.com/debian/ stable main" |  tee /etc/apt/sources.list.d/yarn.list

 #apt update
 #apt install -y yarn

yarn 
yarn build
=======

cd /build/*/
# Implement ICS GSA Mods
BUILDDIR=$(pwd)
echo "BUILDDIR $BUILDDIR"
/ics-gsa/scripts/gsa-mods.sh $BUILDDIR

# Now build gsa
npm ci && npm run build
>>>>>>> isc-v1

 mkdir -p $INSTALL_PREFIX/share/gvm/gsad/web/
 cp -r build/* $INSTALL_PREFIX/share/gvm/gsad/web/

cd /build
rm -rf *
# Clean up after yarn
rm -rf /usr/local/share/.cache
