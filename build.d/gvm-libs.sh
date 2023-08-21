#!/bin/bash
set -Eeuo pipefail
# Source this for the latest release versions
. build.rc

rm -rf /build
mkdir -p /build
cd /build
curl -L -o $gvm_libs.tar.gz https://github.com/greenbone/gvm-libs/archive/$gvm_libs.tar.gz
tar -zxf $gvm_libs.tar.gz
cd /build/*/
# This make sure it will compiel on arm v7
sed -i '/^.*-D_DEFAULT_SOURCE.*/i \ \ \ \ -D_FILE_OFFSET_BITS=64 \\' CMakeLists.txt
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc)
make install
cd /build
rm -rf *


