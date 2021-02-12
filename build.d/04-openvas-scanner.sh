#!/bin/bash 
set -Eeuo pipefail
echo "Building openvas_scanner"   
cd /build
git clone https://github.com/greenbone/openvas-scanner.git
cd /build/*/
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make
make install
cd /build
rm -rf *
