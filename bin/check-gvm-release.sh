#!/bin/bash 
# Create a temp build.rc to diff with the current one and send a nofitication
# if there is a difference with the changes.
# echo "Checking github for the latest releases."
RC=$(mktemp)
# Source the api token
. .token
# 
for repo in gvmd gvm-libs openvas openvas-smb notus-scanner gsa gsad ospd ospd-openvas pg-gvm; do
	VERSION=$(curl -s -H "Authorization: token $Oauth" -L https://api.github.com/repos/greenbone/$repo/releases/latest |  jq -r ".tag_name" )
	#echo "$repo current version is $VERSION"
	VAR=$( echo $repo | tr - _ )
	echo "$VAR=$VERSION" >> $RC
done
for repo in python-gvm gvm-tools greenbone-feed-sync; do 
	python_gvm=$(curl -s -H "Authorization: token $Oauth" -L https://api.github.com/repos/greenbone/$repo/releases/latest |  jq -r ".tag_name")
	#echo "$repo current version is $python_gvm"
	VAR=$(echo $repo | tr - _ )
	echo "$VAR=$python_gvm" >> $RC
done

DIFF=$(diff -y --suppress-common-lines ~/Projects/openvas/build.rc $RC)
if [ $? -ne 0 ]; then
	echo "Something changed"
	echo -e "$DIFF"
else
	echo "no changes"
fi
count=0
for ver  in $(cat $RC); do
	echo -ne "$ver\t"
	((count++))
	if [ $count -eq 3 ]; then
		count=0
		echo
	fi
done
rm $RC
