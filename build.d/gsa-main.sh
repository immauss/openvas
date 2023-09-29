#!/bin/bash
# for some reason, the npm commands do not exit correctly so this will break the build. 
#set -Eeuo pipefail
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
echo "BUILDDIR $BUILDDIR"
/ics-gsa/scripts/gsa-mods.sh $BUILDDIR

#update npm and the browserlist
# these were recomended by npm
echo "Updating npm"
npm install -g npm@10.1.0

echo "Updating npm browserlist"
yes | npx update-browserslist-db@latest

# Now build gsa
echo "Building GSA"
npm install && npm run build

 echo "Storing react bits for later image builds"
 cp -vr build/* /final 


