#!/bin/bash
set -Eeuo pipefail
# Source this for the latest release versions
. build.rc
echo "Building OSPd-openvas"   
cd /build
wget --no-verbose https://github.com/greenbone/ospd-openvas/archive/$ospd_openvas.tar.gz
tar -zxf $ospd_openvas.tar.gz
#git clone --branch stable https://github.com/greenbone/ospd-openvas.git
cd /build/*/
python3 -m pip install -U pip
python3 -m pip install .
cd /build
rm -rf *
