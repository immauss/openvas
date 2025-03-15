#!/bin/bash
# for some reason, the npm commands do not exit correctly so this will break the build. 
set -Eeuo pipefail
# We pass the build tag as an arg here, so let's give it a meaningful name.
tag="$1"
# Source this for the latest release versions
. build.rc
echo "Downloading latest gsa code"  
cd /build
rm -rf *
GSA_VERSION=$(echo $gsa| sed "s/^v\(.*$\)/\1/")
curl -f -L https://github.com/greenbone/gsa/archive/refs/tags/v$GSA_VERSION.tar.gz -o $gsa.tar.gz

tar -xf $gsa.tar.gz

cd /build/*/
# Implement ICS GSA Mods
BUILDDIR=$(pwd)
apt update && apt install patch -y
echo "BUILDDIR $BUILDDIR"
patch -p1 < /ics-gsa/ics-gsa.patch
#/ics-gsa/scripts/gsa-mods.sh $BUILDDIR $tag
if ! [ -f /ver.current ]; then
    echo "Where is /ver.curent?" 
    exit 1
else 
    CVersion=$(cat /ver.current)
    echo "Current Container version is $CVersion . "
fi
CVersion=$(cat /ver.current)
sed -i s/XXXXXXX/$CVersion/ "$BUILDDIR/src/web/pages/login/LoginForm.jsx"

apt update && apt install npm -y 
#update npm and the browserlist
# these were recomended by npm
echo "Updating npm"
npm install -g npm@10.1.0

echo "Updating browser list"
    yes | npx update-browserslist-db@latest || true



# Now build gsa
echo "Building GSA"
npm install 
npm run build 

 echo "Storing react bits for later image builds"
 cp -vr build/* /final 


