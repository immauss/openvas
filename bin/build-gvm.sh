#!/bin/bash
set -Eeuo pipefail
# Source this for the latest release versions
. build.rc

    #
    # install libraries module for the Greenbone Vulnerability Management Solution
    #
    
echo "Starting Build..." 
echo "Updating ssl certs .."
# Needed for the arm/v7 for some reason
/usr/sbin/update-ca-certificates --fresh
echo "Building gvm_libs"
ARCH=$(arch)
echo " Building on $ARCH "
rm -rf /build 
mkdir -p /build 
cd /build 
#wget --no-verbose https://github.com/greenbone/gvm-libs/archive/$gvm_libs.tar.gz 
date
echo "Downloading source for $gvm_libs"
curl -L -o $gvm_libs.tar.gz https://github.com/greenbone/gvm-libs/archive/$gvm_libs.tar.gz
tar -zxf $gvm_libs.tar.gz 
cd /build/*/
mkdir build 
cd build
cmake -DCMAKE_BUILD_TYPE=Release .. 
make 
make install 
cd /build 
rm -rf *

    #
    # install smb module for the OpenVAS Scanner
    #
echo "Building openvas_smb"
cd /build 
wget --no-verbose https://github.com/greenbone/openvas-smb/archive/$openvas_smb.tar.gz 
tar -zxf $openvas_smb.tar.gz 
cd /build/*/ 
mkdir build 
cd build 
cmake -DCMAKE_BUILD_TYPE=Release .. 
make 
make install 
cd /build 
rm -rf *
    
    #
    # Install Greenbone Vulnerability Manager (GVMD)
    #
echo "Building gvmd"
cd /build 
wget --no-verbose https://github.com/greenbone/gvmd/archive/$gvmd.tar.gz 
tar -zxf $gvmd.tar.gz 
cd /build/*/ 
mkdir build 
cd build 
cmake -DCMAKE_BUILD_TYPE=Release .. 
make 
make install 
cd /build 
rm -rf *
    
    #
    # Install Open Vulnerability Assessment System (OpenVAS) Scanner of the Greenbone Vulnerability Management (GVM) Solution
    #
echo "Building openvas_scanner"   
cd /build 
wget --no-verbose https://github.com/greenbone/openvas-scanner/archive/$openvas.tar.gz 
tar -zxf $openvas.tar.gz 
cd /build/*/ 
mkdir build 
cd build 
cmake -DCMAKE_BUILD_TYPE=Release .. 
make 
make install 
cd /build 
rm -rf *
    
    #
    # Install Greenbone Security Assistant (GSA)
    #
echo "Building gsa"  
cd /build 
wget --no-verbose https://github.com/greenbone/gsa/archive/$gsa.tar.gz 
tar -zxf $gsa.tar.gz 
cd /build/*/ 
mkdir build 
cd build 
cmake -DCMAKE_BUILD_TYPE=Release .. 
make 
make install 
cd /build 
rm -rf *
    
    #
    # Install Greenbone Vulnerability Management Python Library
    #
#echo "Installing python_gvm"
#python3 -m pip install python-gvm==$python_gvm
#python3 -m pip install python-gvm
    
    
    #
    # Install Open Scanner Protocol daemon (OSPd)
    #
echo "Building Openvas"
cd /build 
wget --no-verbose https://github.com/greenbone/ospd/archive/$ospd.tar.gz 
tar -zxf $ospd.tar.gz 
cd /build/*/ 
python3 setup.py install 
cd /build 
rm -rf *
    
    #
    # Install Open Scanner Protocol for OpenVAS
    #
echo "Building OSPd"   
cd /build 
wget --no-verbose https://github.com/greenbone/ospd-openvas/archive/$ospd_openvas.tar.gz 
tar -zxf $ospd_openvas.tar.gz 
cd /build/*/ 
python3 setup.py install 
cd /build 
rm -rf *
    
    #
    # Install GVM-Tools
    #
echo "pip install GVM-tools"
python3 -m pip install gvm-tools==$gvm_tools 

    # 
    # Make sure all libraries are linked and add a random directory suddenly needed by ospd :/
    #

echo "/usr/local/lib" > /etc/ld.so.conf.d/openvas.conf
ldconfig  




