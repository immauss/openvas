#!/bin/bash
NODE_VERSION=node_20.x
NODE_KEYRING=/usr/share/keyrings/nodesource.gpg
DISTRIBUTION=nodistro
. /build.rc
echo "Downloading latest gsa code"  
GSA_VERSION=$(echo $gsa| sed "s/^v\(.*$\)/\1/")
# Remove any old keys
rm -f /etc/apt/trusted.gpg.d/nodesource.gpg
rm -f /usr/share/keyrings/nodesource.gpg

# Download and add the NodeSource key
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
  | gpg --dearmor -o $NODE_KEYRING

echo "deb [signed-by=$NODE_KEYRING] https://deb.nodesource.com/$NODE_VERSION $DISTRIBUTION main" >  /etc/apt/sources.list.d/nodesource.list
echo "deb-src [signed-by=$NODE_KEYRING] https://deb.nodesource.com/$NODE_VERSION $DISTRIBUTION main" >> /etc/apt/sources.list.d/nodesource.list
#gpg --no-default-keyring --keyring "$NODE_KEYRING" --list-keys
apt update && apt install nodejs -y 

#npm audit fix 
#echo "Updating npm"
#npm install -g npm@10.1.0
#echo "Updating npm browserlist"
#npm install
