#!/bin/bash
set -Eeuo pipefail
# Source this for the latest release versions
. build.rc

echo "Building openvas_smb"
cd /build
wget --no-verbose https://github.com/greenbone/openvas-smb/archive/$openvas_smb.tar.gz
tar -zxf $openvas_smb.tar.gz
# Fixes for issue #125
sed -i 's/ncacn_ip_tcp:%s/ncacn_ip_tcp:%s[sign]/'   openvas-smb*/samba/lib/com/dcom/main.c
sed -i "s/const uint16 COM_MINOR_VERSION = 1/const uint16 COM_MINOR_VERSION = 7/" openvas-smb*/samba/librpc/idl/orpc.idl
cd /build/*/
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc)
make install
cd /build
rm -rf *
