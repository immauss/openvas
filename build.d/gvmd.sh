#!/bin/bash
set -Eeuo pipefail
# Source this for the latest release versions
. build.rc
echo "Building gvmd"
cd /build
wget --no-verbose https://github.com/greenbone/gvmd/archive/$gvmd.tar.gz
tar -zxf $gvmd.tar.gz
cd /build/*/
mkdir build
cd build
ls -l /usr/include/postgresql/13/server
cmake -DPostgreSQL_TYPE_INCLUDE_DIR=/usr/include/postgresql/13/server \
  -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc)
make install
cd /build
rm -rf *
