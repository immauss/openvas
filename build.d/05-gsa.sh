#!/bin/bash 
set -Eeuo pipefail
echo "Building gsa"  
cd /build
git clone https://github.com/greenbone/gsa.git
cd /build/*/
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make
make install
cd /build
rm -rf *
