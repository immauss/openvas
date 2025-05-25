#!/bin/bash
NODE_VERSION=node_20.x
NODE_KEYRING=/usr/share/keyrings/nodesource.gpg
DISTRIBUTION=bookworm
. /build.rc
echo "Downloading latest gsa code"  
GSA_VERSION=$(echo $gsa| sed "s/^v\(.*$\)/\1/")
mkdir -p /gsa
cd /gsa
curl -f -L https://github.com/greenbone/gsa/archive/refs/tags/v$GSA_VERSION.tar.gz -o $gsa.tar.gz
tar -xf $gsa.tar.gz
rm $gsa.tar.gz
cd *
SRCDIR=$(pwd)
echo "$SRCDIR" > /sourcedir
echo "Source directory is $SRCDIR"
mv $SRCDIR /gsa/gsa.latest
cd /gsa/gsa.latest
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor | tee "$NODE_KEYRING" >/dev/null && \
    echo "deb [signed-by=$NODE_KEYRING] https://deb.nodesource.com/$NODE_VERSION $DISTRIBUTION main" | tee /etc/apt/sources.list.d/nodesource.list
apt update && apt install nodejs -y 

npm install vite
npm audit fix 
echo "Updating npm"
npm install -g npm@10.1.0
echo "Updating npm browserlist"
npm install
