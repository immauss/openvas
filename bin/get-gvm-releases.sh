#!/bin/bash 
# create the build.rc file with the latest release versions of each tool
echo "Checking github for the latest releases."
rm build.rc
# Source the api token
. .token
COUNT=0
rm versions.md
echo "# Greenbone Versions in Latest image: #
Component | Version | | Component | Version
----------|----------|-|----------|---------" > versions.md
for repo in pg-gvm notus-scanner gvmd openvas openvas-smb gvm-libs openvas-scanner gsa ospd ospd-openvas ; do 
	VERSION=$(curl -s -H "Authorization: token $Oauth" -L https://api.github.com/repos/greenbone/$repo/releases/latest |  jq -r ".assets[].browser_download_url" | sed "s/^.*download\/\(v.*\)\/.*$/\1/" | head -1)
	echo "$repo current version is $VERSION"
	VAR=$( echo $repo | tr - _ )
	echo "$VAR=$VERSION" >> build.rc
	COUNT=$( expr $COUNT + 1 )
	LF=$( expr $COUNT % 2)
	if [ $LF -eq 1 ]; then
		echo -n "| $VAR | \$${repo} |" >> versions.md
	else
		echo " | $VAR | \$${repo} |" >> versions.md
	fi	
done
for repo in python-gvm gvm-tools; do 
	python_gvm=$(curl -s -H "Authorization: token $Oauth" -L https://api.github.com/repos/greenbone/$repo/releases/latest |  jq -r ".tarball_url" | awk -F/ '{print $NF}' )
	echo "$repo current version is $python_gvm"
	VAR=$(echo $repo | tr - _ )
	echo "$VAR=$python_gvm" >> build.rc
	COUNT=$( expr $COUNT + 1 )
	LF=$( expr $COUNT % 2)
	if [ $LF -eq 1 ]; then
		echo -n "| $VAR | \$${repo} |" >> versions.md
	else
		echo " | $VAR | \$${repo} |" >> versions.md
	fi	
done
