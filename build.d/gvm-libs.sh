#!/bin/bash
set -Eeuo pipefail
# Source this for the latest release versions
. build.rc

rm -rf /build
mkdir -p /build
cd /build
#curl -L -o $gvm_libs.tar.gz https://github.com/greenbone/gvm-libs/archive/$gvm_libs.tar.gz
#tar -zxf $gvm_libs.tar.gz
apt update && apt install -y git
git clone --branch stable https://github.com/greenbone/gvm-libs.git
cd /build/*/
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make
make install
cd /build
rm -rf *


