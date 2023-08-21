#!/bin/bash
set -Eeuo pipefail
# Source this for the latest release versions
. build.rc
echo "Building openvas_scanner"   
cd /build
wget --no-verbose https://github.com/greenbone/openvas-scanner/archive/$openvas.tar.gz
tar -zxf $openvas.tar.gz
cd /build/*/
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
#cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS="-g3" -DCMAKE_CXX_FLAGS="-g3" ..
make -j$(nproc)
make install
cd /build
rm -rf *
