#!/bin/bash
set -Eeuo pipefail
# Source this for the latest release versions
. build.rc
. build.d/env.sh

echo "Building openvas_smb"
cd /build
wget --no-verbose https://github.com/greenbone/openvas-smb/archive/$openvas_smb.tar.gz
tar -zxf $openvas_smb.tar.gz

cd /build/*/
mkdir build
cd build

cmake -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc)
make install
cd /build
rm -rf *
echo "Build openvas_smb complete"
echo "Cleaning up"
# Copy these to / because gvmd and openvas depend on gvm-libs and openvas-smb
cp -rp /artifacts/* / || true