#!/bin/bash
set -Eeuo pipefail
# Source this for the latest release versions
. build.rc
echo "Building OSPd-openvas"   
cd /build
wget --no-verbose https://github.com/greenbone/ospd-openvas/archive/$ospd_openvas.tar.gz
tar -zxf $ospd_openvas.tar.gz
cd /build/*/
echo " Find"
find . -name setup.py
echo " Found ?"
pwd 



python3 -m pip install --break-system-packages .

cd /build
rm -rf *
