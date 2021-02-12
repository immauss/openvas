#!/bin/bash
set -Eeuo pipefail
echo "install curl"
apt-get update
apt-get install -y gnupg curl

echo "Install the postgres repo"
echo "deb http://apt.postgresql.org/pub/repos/apt focal-pgdg main" > /etc/apt/sources.list.d/pgdg.list
curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

apt-get update 

echo "install required packages"
{ cat <<EOF
bison
build-essential
ca-certificates
cmake
curl
doxygen
gcc
gcc-mingw-w64
geoip-database
git
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
libnet-dev
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

echo "Install nodejs"
# Install Node.js
curl -sL https://deb.nodesource.com/setup_10.x | bash -
apt-get install nodejs -yq --no-install-recommends

echo "Install yarn"
# Install Yarn
curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
apt-get update
apt-get install yarn -yq --no-install-recommends


echo "Starting Build..." 
echo "Building gvm_libs"
rm -rf /build 
mkdir -p /build 
cd /build 
git clone https://github.com/greenbone/gvm-libs.git
cd /build/*/
mkdir build 
cd build
cmake -DCMAKE_BUILD_TYPE=Release .. 
make 
make install 
cd /build 
rm -rf *

echo "Building openvas_smb"
cd /build 
git clone https://github.com/greenbone/openvas-smb.git
cd /build/*/ 
mkdir build 
cd build 
cmake -DCMAKE_BUILD_TYPE=Release .. 
make 
make install 
cd /build 
rm -rf *
    
echo "Building gvmd"
cd /build 
git clone https://github.com/greenbone/gvmd.git
cd /build/*/ 
mkdir build 
cd build 
cmake -DCMAKE_BUILD_TYPE=Release .. 
make 
make install 
cd /build 
rm -rf *
    
echo "Building openvas_scanner"   
cd /build 
git clone https://github.com/greenbone/openvas-scanner.git
cd /build/*/ 
mkdir build 
cd build 
cmake -DCMAKE_BUILD_TYPE=Release .. 
make 
make install 
cd /build 
rm -rf *
    
echo "Building gsa"  
cd /build 
git clone https://github.com/greenbone/gsa.git
cd /build/*/ 
mkdir build 
cd build 
cmake -DCMAKE_BUILD_TYPE=Release .. 
make 
make install 
cd /build 
rm -rf *
    
echo "Installing python_gvm"
#python3 -m pip install python-gvm==$python_gvm_version
python3 -m pip install python-gvm
    
echo "Building ospd"
cd /build 
git clone https://github.com/greenbone/ospd.git
cd /build/*/ 
python3 setup.py install 
cd /build 
rm -rf *
    
echo "Building ospd-openvas"   
cd /build 
git clone https://github.com/greenbone/ospd.git
cd /build/*/ 
python3 setup.py install 
cd /build 
rm -rf *
    
echo "Installing GVM-tools"
python3 -m pip install gvm-tools==$gvm_tools_version 

echo "Ensure everything is linked properly"
echo "/usr/local/lib" > /etc/ld.so.conf.d/openvas.conf
ldconfig  




