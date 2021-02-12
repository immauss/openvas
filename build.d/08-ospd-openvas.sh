#!/bin/bash 
set -Eeuo pipefail
echo "Building ospd-openvas"   
cd /build
git clone https://github.com/greenbone/ospd-openvas.git
#git clone --single-branch --branch ospd-openvas-20.08 https://github.com/greenbone/ospd.git
cd /build/*/
python3 setup.py install
cd /build
rm -rf *

