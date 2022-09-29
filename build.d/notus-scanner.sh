#!/bin/bash
INSTALL_PREFIX="/usr/local/"
set -Eeuo pipefail
# Source this for the latest release versions
. build.rc
#apt install git -y 
echo "Building notus-scanner"  
cd /build
wget --no-verbose https://github.com/greenbone/notus-scanner/archive/$notus_scanner.tar.gz
tar -zxf $notus_scanner.tar.gz
ls -l
cd /build/*/
 python3 -m pip install . 
 ls -l /usr/local/bin/ |  tee /local-bin.txt


cd /build
rm -rf *
