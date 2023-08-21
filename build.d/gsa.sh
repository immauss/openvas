#!/bin/bash
INSTALL_PREFIX="/usr/local/"
set -Eeuo pipefail
# Source this for the latest release versions
. build.rc
echo "Building gsa"  
cd /build
GSA_VERSION=$(echo $gsa| sed "s/^v\(.*$\)/\1/")
curl -f -L https://github.com/greenbone/gsa/archive/refs/tags/v$GSA_VERSION.tar.gz -o $gsa.tar.gz

tar -xf $gsa.tar.gz
apt remove nodejs yarn -y 
ls -l
cd /build/*/
export NODE_VERSION=node_14.x
export KEYRING=/usr/share/keyrings/nodesource.gpg
export DISTRIBUTION="bullseye"

curl -fsSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor |  tee "$KEYRING" >/dev/null
gpg --no-default-keyring --keyring "$KEYRING" --list-keys
echo "deb [signed-by=$KEYRING] https://deb.nodesource.com/$NODE_VERSION $DISTRIBUTION main" |  tee /etc/apt/sources.list.d/nodesource.list
echo "deb-src [signed-by=$KEYRING] https://deb.nodesource.com/$NODE_VERSION $DISTRIBUTION main" |  tee -a /etc/apt/sources.list.d/nodesource.list


 apt update
 apt install -y nodejs

curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg |  apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" |  tee /etc/apt/sources.list.d/yarn.list

 apt update
 apt install -y yarn

yarn 
yarn build

 mkdir -p $INSTALL_PREFIX/share/gvm/gsad/web/
 cp -r build/* $INSTALL_PREFIX/share/gvm/gsad/web/




cd /build
rm -rf *
# Clean up after yarn
rm -rf /usr/local/share/.cache
# Now we build gsad
GSAD_VERSION=$(echo $gsad| sed "s/^v\(.*$\)/\1/")
curl -f -L https://github.com/greenbone/gsad/archive/refs/tags/v$GSAD_VERSION.tar.gz -o gsad-$GSAD_VERSION.tar.gz
tar xvf gsad-$GSAD_VERSION.tar.gz
cd /build/*/
cmake -j$(nproc) /build/gsad-$GSAD_VERSION \
	-DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
	-DCMAKE_BUILD_TYPE=Release \
	-DSYSCONFDIR=/usr/local/etc \
	-DLOCALSTATEDIR=/var \
	-DGVMD_RUN_DIR=/run/gvmd \
	-DGSAD_RUN_DIR=/run/gsad \
	-DLOGROTATE_DIR=/etc/logrotate.d

make install
cd /build
rm -rf *
