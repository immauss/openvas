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
ls -l
cd /build/*/
yarnpkg
yarnpkg build
mkdir -p $INSTALL_PREFIX/share/gvm/gsad/web/
cp -r build/* $INSTALL_PREFIX/share/gvm/gsad/web/

cd /build
rm -rf *
# Clean up after yarn
rm -rf /usr/local/share/.cache
GSAD_VERSION=$GSA_VERSION
# Now we build gsad
curl -f -L https://github.com/greenbone/gsad/archive/refs/tags/v$GSAD_VERSION.tar.gz -o gsad-$GSAD_VERSION.tar.gz
tar xvf gsad-$GSAD_VERSION.tar.gz
cd /build/*/
cmake /build/gsad-$GSA_VERSION \
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
