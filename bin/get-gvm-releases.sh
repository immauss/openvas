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

for repo in gvmd gvm-libs openvas openvas-scanner openvas-smb notus-scanner gsa gsad ospd ospd-openvas pg-gvm; do
	VERSION=$(curl -s -H "Authorization: token $Oauth" -L https://api.github.com/repos/greenbone/$repo/releases/latest |  jq -r ".tag_name") 
	echo "$repo current version is $VERSION"
	VAR=$( echo $repo | tr - _ )
	echo "$VAR=$VERSION" >> build.rc
	COUNT=$( expr $COUNT + 1 )
	LF=$( expr $COUNT % 2)
	if [ $LF -eq 1 ]; then
		echo -n "| $VAR | $VERSION |" >> versions.md
	else
		echo " | $VAR | $VERSION |" >> versions.md
	fi	
done
for repo in python-gvm gvm-tools greenbone-feed-sync; do 
	VERSION=$(curl -s -H "Authorization: token $Oauth" -L https://api.github.com/repos/greenbone/$repo/releases/latest | jq -r ".tag_name")
	echo "$repo current version is $VERSION"
	VAR=$(echo $repo | tr - _ )
	echo "$VAR=$VERSION" >> build.rc
	COUNT=$( expr $COUNT + 1 )
	LF=$( expr $COUNT % 2)
	if [ $LF -eq 1 ]; then
		echo -n "| $VAR | $VERSION |" >> versions.md
	else
		echo " | $VAR | $VERSION |" >> versions.md
	fi	
done
