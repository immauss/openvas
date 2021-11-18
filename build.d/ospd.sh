#!/bin/bash
set -Eeuo pipefail
# Source this for the latest release versions
. build.rc
echo "Building ospd"
cd /build
#wget --no-verbose https://github.com/greenbone/ospd/archive/$ospd.tar.gz
#tar -zxf $ospd.tar.gz
git clone --branch stable https://github.com/greenbone/ospd.git 
cd /build/*/
python3 -m pip install .
cd /build
rm -rf *
