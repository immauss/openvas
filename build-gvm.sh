#!/bin/bash
apt-get update
apt-get install -y gnupg curl

echo "deb http://apt.postgresql.org/pub/repos/apt focal-pgdg main" > /etc/apt/sources.list.d/pgdg.list
curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

apt-get upgrade -y

{ cat <<EOF
bison
build-essential
ca-certificates
cmake
curl
gcc
gcc-mingw-w64
geoip-database
gnutls-bin
graphviz
heimdal-dev
ike-scan
libgcrypt20-dev
libglib2.0-dev
libgnutls28-dev
libgpgme11-dev
libgpgme-dev
libhiredis-dev
libical-dev
libksba-dev
libldap2-dev
libmicrohttpd-dev
libnet-snmp-perl
libpcap-dev
libpopt-dev
libsnmp-dev
libssh-gcrypt-dev
libxml2-dev
locales-all
mailutils
net-tools
nmap
nsis
openssh-client
openssh-server
perl-base
pkg-config
postfix
postgresql-12
postgresql-server-dev-12
python3-defusedxml
python3-dialog
python3-lxml
python3-paramiko
python3-pip
python3-polib
python3-psutil
python3-setuptools
redis-server
redis-tools
rsync
smbclient
sshpass
texlive-fonts-recommended
texlive-latex-extra
uuid-dev
wapiti
wget
whiptail
xml-twig-tools
xsltproc
EOF
} | xargs apt-get install -yq --no-install-recommends


# Install Node.js
curl -sL https://deb.nodesource.com/setup_10.x | bash -
apt-get install nodejs -yq --no-install-recommends


# Install Yarn
curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
#apt-get update
apt-get install yarn -yq --no-install-recommends


rm -rf /var/lib/apt/lists/*

gvm_libs_version="v20.8.0" \
openvas_scanner_version="v20.8.0" \
gvmd_version="v20.8.0" \
gsa_version="v20.8.0" \
open_scanner_protocol_daemon="v20.8.1" \
ospd_openvas="v20.8.0" \
gvm_tools_version="v2.1.0" \
openvas_smb="v1.0.5" \
python_gvm_version="v1.6.0"



    #
    # install libraries module for the Greenbone Vulnerability Management Solution
    #
    
echo "Starting Build..." 
echo "Building gvm_libs"
rm -rf /build &&\
mkdir -p /build && \
cd /build && \
pwd && \
wget --no-verbose https://github.com/greenbone/gvm-libs/archive/$gvm_libs_version.tar.gz && \
tar -zxf $gvm_libs_version.tar.gz && \
ls -l /build/ && \
cd /build/*/ && \
mkdir build && \
cd build && \
cmake -DCMAKE_BUILD_TYPE=Release .. && \
make && \
make install && \
cd /build && \
rm -rf *

    #
    # install smb module for the OpenVAS Scanner
    #
echo "Building openvas_smb"
cd /build && \
wget --no-verbose https://github.com/greenbone/openvas-smb/archive/$openvas_smb.tar.gz && \
tar -zxf $openvas_smb.tar.gz && \
cd /build/*/ && \
mkdir build && \
cd build && \
cmake -DCMAKE_BUILD_TYPE=Release .. && \
make && \
make install && \
cd /build && \
rm -rf *
    
    #
    # Install Greenbone Vulnerability Manager (GVMD)
    #
echo "Building gvmd"
cd /build && \
wget --no-verbose https://github.com/greenbone/gvmd/archive/$gvmd_version.tar.gz && \
tar -zxf $gvmd_version.tar.gz && \
cd /build/*/ && \
mkdir build && \
cd build && \
cmake -DCMAKE_BUILD_TYPE=Release .. && \
make && \
make install && \
cd /build && \
rm -rf *
    
    #
    # Install Open Vulnerability Assessment System (OpenVAS) Scanner of the Greenbone Vulnerability Management (GVM) Solution
    #
echo "Building openvas_scanner"   
cd /build && \
wget --no-verbose https://github.com/greenbone/openvas-scanner/archive/$openvas_scanner_version.tar.gz && \
tar -zxf $openvas_scanner_version.tar.gz && \
cd /build/*/ && \
mkdir build && \
cd build && \
cmake -DCMAKE_BUILD_TYPE=Release .. && \
make && \
make install && \
cd /build && \
rm -rf *
    
    #
    # Install Greenbone Security Assistant (GSA)
    #
echo "Building gsa"  
cd /build && \
wget --no-verbose https://github.com/greenbone/gsa/archive/$gsa_version.tar.gz && \
tar -zxf $gsa_version.tar.gz && \
cd /build/*/ && \
mkdir build && \
cd build && \
cmake -DCMAKE_BUILD_TYPE=Release .. && \
make && \
make install && \
cd /build && \
rm -rf *
    
    #
    # Install Greenbone Vulnerability Management Python Library
    #
echo "Installing python_gvm"
python3 -m pip install python-gvm==$python_gvm_version
    
    
    #
    # Install Open Scanner Protocol daemon (OSPd)
    #
echo "Building Openvas"
cd /build && \
wget --no-verbose https://github.com/greenbone/ospd/archive/$open_scanner_protocol_daemon.tar.gz && \
tar -zxf $open_scanner_protocol_daemon.tar.gz && \
cd /build/*/ && \
python3 setup.py install && \
cd /build && \
rm -rf *
    
    #
    # Install Open Scanner Protocol for OpenVAS
    #
echo "Building OSPd"   
cd /build && \
wget --no-verbose https://github.com/greenbone/ospd-openvas/archive/$ospd_openvas.tar.gz && \
tar -zxf $ospd_openvas.tar.gz && \
cd /build/*/ && \
python3 setup.py install && \
cd /build && \
rm -rf *
    
    #
    # Install GVM-Tools
    #
echo "Building GVM-tools"
python3 -m pip install gvm-tools==$gvm_tools_version && \
echo "/usr/local/lib" > /etc/ld.so.conf.d/openvas.conf
ldconfig  

    # 
    # Make sure all libraries are linked and add a random directory suddenly needed by ospd :/
    #
echo "Done Building"
mkdir /var/run/ospd

echo "Doing some cleanup"


{ cat <<EOF
bison
build-essential
cmake
curl
gcc
gcc-mingw-w64
uuid-dev
EOF
} | xargs apt-get -y remove
apt auto-remove -y 
rm -rf /var/lib/apt/lists/*
rm -rf /build /tmp/*


