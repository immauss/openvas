#!/bin/bash
set -Eeuo pipefail
# Source this for the latest release versions
. build.rc
echo "Building gsa"  
cd /build
wget --no-verbose https://github.com/greenbone/gsa/archive/$gsa.tar.gz
tar -zxf $gsa.tar.gz
cd /build/*/
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make
make install
cd /build
rm -rf *
