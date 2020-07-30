#!/bin/bash

apt-get update

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
libical2-dev
libksba-dev
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
perl-base
pkg-config
postfix
postgresql
postgresql-contrib
postgresql-server-dev-all
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
apt-get update
apt-get install yarn -yq --no-install-recommends


rm -rf /var/lib/apt/lists/*
