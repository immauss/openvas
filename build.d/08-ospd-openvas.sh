#!/bin/bash 
set -Eeuo pipefail
echo "Building ospd-openvas"   
cd /build
git clone https://github.com/greenbone/ospd.git
cd /build/*/
python3 setup.py install
cd /build
rm -rf *
