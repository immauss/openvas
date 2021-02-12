#!/bin/bash 
set -Eeuo pipefail
echo "Building gvm_libs"
rm -rf /build
mkdir -p /build
cd /build
git clone https://github.com/greenbone/gvm-libs.git
cd /build/*/
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make
make install
cd /build
rm -rf *
