#!/bin/bash
echo "Building gvmd"
cd /build
git clone https://github.com/greenbone/gvmd.git
cd /build/*/
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make
make install
cd /build
rm -rf *
