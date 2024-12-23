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
# install the needed dev dependancy.
# which is not needed elsewhere.
apt install heimdal-dev -y
cmake -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc)
make install
cd /build
rm -rf *
# Remove build dependancies so they dont' conflict others.
grep "Commandline: apt install" /var/log/apt/history.log | tail -1 | \
    sed 's/Commandline: apt install //' | xargs apt remove -y
