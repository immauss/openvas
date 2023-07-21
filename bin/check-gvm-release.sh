#!/bin/bash 
# Create a temp build.rc to diff with the current one and send a nofitication
# if there is a difference with the changes.
# echo "Checking github for the latest releases."
RC=$(mktemp)
# Source the api token
. .token
# 
for repo in pg-gvm notus-scanner gvmd openvas openvas-smb gvm-libs openvas-scanner gsa ospd ospd-openvas ; do
	VERSION=$(curl -s -H "Authorization: token $Oauth" -L https://api.github.com/repos/greenbone/$repo/releases/latest |  jq -r ".assets[].browser_download_url" | sed "s/^.*download\/\(v.*\)\/.*$/\1/" | head -1)
	#echo "$repo current version is $VERSION"
	VAR=$( echo $repo | tr - _ )
	echo "$VAR=$VERSION" >> $RC
done
for repo in python-gvm gvm-tools greenbone-feed-sync; do 
	python_gvm=$(curl -s -H "Authorization: token $Oauth" -L https://api.github.com/repos/greenbone/$repo/releases/latest |  jq -r ".tarball_url" | awk -F/ '{print $NF}' )
	#echo "$repo current version is $python_gvm"
	VAR=$(echo $repo | tr - _ )
	echo "$VAR=$python_gvm" >> $RC
done

DIFF=$(diff /home/scott/Projects/openvas/build.rc $RC)
if [ $? -ne 0 ]; then
	echo "Something changed"
	echo -e "$DIFF"
else
	echo "no changes"
fi
cat $RC
rm $RC
