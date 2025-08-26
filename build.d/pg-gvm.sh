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
export PATH=/usr/lib/postgresql/13/bin:$PATH
pg_config --version
pg_config --includedir-server
ls -l $(/usr/lib/postgresql/13/bin/pg_config --includedir-server)/postgres.h
cd /build/*/
  mkdir build
  cd build
  cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_PROGRAM_PATH=/usr/lib/postgresql/13/bin \
    -DPostgreSQL_TYPE_INCLUDE_DIR="/usr/include/postgresql/13/server" \
    -DPostgreSQL_INCLUDE_DIRS="/usr/include/postgresql/13" \
    -DPostgreSQL_LIBRARY_DIRS="$(pg_config --libdir)"
  make  -j$(nproc)
  make install

cd /build
rm -rf *
