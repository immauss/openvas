#!/bin/bash 
# create the build.rc file with the latest release versions of each tool
echo "Checking github for the latest releases."
rm build.rc
# Source the api token
. .token
for repo in pg-gvm notus-scanner gvmd openvas openvas-smb gvm-libs openvas-scanner gsa ospd ospd-openvas; do

	VERSION=$(curl -s -H "Authorization: token $Oauth" -L https://api.github.com/repos/greenbone/$repo/releases/latest |  jq -r ".assets[].browser_download_url" | sed "s/^.*download\/\(v.*\)\/.*$/\1/" | head -1)
	echo "$repo current version is $VERSION"
	VAR=$( echo $repo | tr - _ )
	echo "$VAR=$VERSION" >> build.rc
done
for repo in python-gvm gvm-tools greenbone-feed-sync; do 
	python_gvm=$(curl -s -H "Authorization: token $Oauth" -L https://api.github.com/repos/greenbone/$repo/releases/latest | jq -r ".tarball_url" | awk -F/ '{print $NF}' )
	echo "$repo current version is $python_gvm"
	VAR=$(echo $repo | tr - _ )
	echo "$VAR=$python_gvm" >> build.rc
done
