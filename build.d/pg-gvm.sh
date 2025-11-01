#!/bin/bash
INSTALL_DIR="/usr/local/"
set -Eeuo pipefail
# Source this for the latest release versions
. build.rc
#apt install git -y 
echo "Building pg-gvm"  
cd /build
wget --no-verbose https://github.com/greenbone/pg-gvm/archive/$pg_gvm.tar.gz
tar -zxf $pg_gvm.tar.gz
ls -l
cd /build/*/
  mkdir build
  cd build
  cmake .. -DCMAKE_BUILD_TYPE=Release
  make  -j$(nproc)
  make install

cd /build
rm -rf *
