#!/bin/bash
set -Eeuo pipefail
# Source this for the latest release versions
. build.rc

echo "Building openvas_smb"
cd /build
wget --no-verbose https://github.com/greenbone/openvas-smb/archive/$openvas_smb.tar.gz
tar -zxf $openvas_smb.tar.gz
sed -i 's/ncacn_ip_tcp:%s/ncacn_ip_tcp:%s[sign]/'   openvas-smb*/samba/lib/com/dcom/main.c
cd /build/*/
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make
make install
cd /build
rm -rf *
