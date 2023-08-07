#!/bin/bash
# This script will refresh the data in the openvas docker image on dockerhub
# It will include a new db dump and the contents of /data/var-lib
# This should run from a cron with a long enough sleep to make sure
# the gvmd has updated the DB before creating the archive and pushing
# to github. It's probably not going to be useful to anyone but me
# but the output will benefit all. 

# Set start dir
WorkDir=$(pwd)
# Tag to work with. Normally latest but might be using new tag during upgrades.
TAG="latest"
SQLBU="${TAG}.base.sql"
TAR="${TAG}.var-lib.tar.xz"
# Temp working directory ... needs enough space to pull the entire feed and then compress it. ~2G
TWD="/var/lib/openvas/" # Must have a trailing "/"
STIME="30m" # time between resync and archiving.
# First, clean TWD and  make sure there's enough storage available before doing anything.
if [ -d $TWD ]; then # Make sure the TWD exists and is a directory so we don't accidently destroy the system.
	echo " Cleaning $TWD "
	cd $TWD
	rm -rf ${TWD}*
fi
SPACE=$(df -h "$TWD" | awk /G/'{print $4}' | sed "s/G//")
if [ -z $SPACE ]; then
	echo "Check available storage"
	exit
elif [ $SPACE -le 4 ]; then
	echo "only ${SPACE}G of space on /var/lib/docker ... bailing out."
	exit
fi


# Force a pull of the latest image.
docker pull immauss/openvas:$TAG
echo "Starting container for an update"
docker run -d -e NEWDB=true --name updater immauss/openvas:$TAG
date
echo "Sleeping for $STIME to make sure the feeds are updated in the db"
sleep $STIME
CONTINUE=0
COUNTER=0
WAIT="45" # Time after sync to wait for DB to finish updating.
while  [ $CONTINUE -eq 0 ] && [ $COUNTER -le $WAIT ]; do
	if docker logs updater 2>&1 | grep -qs "Updating VTs in database ... done"; then
		CONTINUE=1
		echo "looks like it's done"
	else
		echo "Not done yet."
	fi
	COUNTER=$( expr $COUNTER + 1)
	sleep 1m
done

if [ $COUNTER -gt $WAIT ]; then
	echo "Waited for success in logs for > $WAIT minutes. "
	echo "Bailing out now."
	docker logs -n 30 updater
	exit
fi

cd $TWD
echo "First copy the feeds from the container"
docker cp updater:/data/var-lib .
echo "Now dump the db from postgres"
docker exec -i updater su -c "/usr/lib/postgresql/13/bin/pg_dumpall" postgres > ./$SQLBU 

echo "Stopping update container"
docker stop updater
echo "Dumping container logs to /var/log/refresh.log"
date >> /var/log/refresh.log
docker logs updater >> /var/log/refresh.log
docker rm updater
# Give the data a timestamp
date > var-lib/update.ts
echo "Compress and archive the data"
#Exclude the gnupg dir as this should be unique for each installation. 
tar cJf $TAR --exclude=var-lib/gvm/gvmd/gnupg \
	--exclude=var-lib/gvm/CA \
	--exclude=var-lib/gvm/private \
	var-lib
xz -1 $SQLBU
SQL_SIZE=$( ls -l $SQLBU.xz | awk '{print $5}')
FEED_SIZE=$( ls -l $TAR | awk '{print $5'})
echo "Check the file sizes for sanity"
if [ $SQL_SIZE -le 2000 ] || [ $FEED_SIZE -le 2000 ]; then
	echo "SQL_SIZE = $SQL_SIZE : FEED_SIZE = $FEED_SIZE: Failing out"
	logger -t db-refresh "SQL_SIZE = $SQL_SIZE : FEED_SIZE = $FEED_SIZE: Failing out"
	exit
fi
echo " Push updates to www"
scp *.xz push@www.immauss.com:/var/www/html/drupal/openvas/
if [ $? -ne 0 ]; then
	echo "SCP of new db failed $?"
	logger -t db-refresh "SCP of new db failed $?"
	exit
fi
# Now rebuild the image
cd $WorkDir
date > update.ts
docker buildx build -f Dockerfile.refresh --build-arg TAG=${TAG} --target final -t immauss/openvas:$TAG --platform linux/arm64,linux/amd64,linux/arm/v7 --push .
if [ $? -ne 0 ]; then
	echo "Build failed."
	exit
fi

echo "Cleaning up"
cd $TWD
rm -rf *
echo "All done"


