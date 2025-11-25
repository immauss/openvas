#!/bin/bash
# This script is run after single.sh 
# it runs in the container. 
# it will perform a feed-sync and then wait for the feeds to be fully updated in the DB. 
# it will then create a DB backup and an archive of the feeds for inclusion in new images.
# it should be added to the running container using a custom docker-compose.yaml to start the image.
# it should run once and then be deleted on exit.
# it needs to run with the output files going to a bind mount @ /home/scott/Projects/openvas/
# it should bind mount the gvm_wait_feeds.sh to /scripts/ 
# need to find a way to make it log 
# we'll use this 
echo "Starting Feed Refresh"
date
touch /mnt/output/feed-update-running
apt update && apt install libxml2-utils -y

GLOBALS="globals.sql"
GVMDB="gvmd.sql"
TAR="var-lib.tar"
WD="$(mktemp -d)"
chmod 777 $WD

# source the wait function.
. /scripts/gvm_wait_feeds.sh
# Run a feed sync
/scripts/sync.sh 

gvm_wait_feeds --host $(hostname) --interval 120 --timeout 3600
if [ $? -ne 0 ]; then
    echo "Feeds did not finish synchroninzg within timeout"
	exit
fi

cd $WD
echo "First copy the feeds from the container"
cp -rpf /data/var-lib .

echo "Now dump the db from postgres"
su -c "/usr/lib/postgresql/13/bin/pg_dumpall --globals-only" postgres | xz -1 > ./$GLOBALS.xz
su -c "/usr/lib/postgresql/13/bin/pg_dump -Fc -f ./$GVMDB gvmd" postgres
date > var-lib/update.ts
echo "Compress and archive the data"
#Exclude the gnupg dir as this should be unique for each installation. 
echo "....Creating $TAR"
tar cf $TAR --exclude=var-lib/gvm/gvmd/gnupg \
	--exclude=var-lib/gvm/CA \
	--exclude=var-lib/gvm/private \
	var-lib
echo "....Compressing $GVMDB"
xz -T10 -9 $GVMDB
echo "....Compressing $TAR"
xz -T10 -9 $TAR
SQL_SIZE=$( ls -l $GVMDB.xz | awk '{print $5}')
FEED_SIZE=$( ls -l $TAR.xz | awk '{print $5'})
echo "Check the file sizes for sanity"
if [ $SQL_SIZE -le 2000 ] || [ $FEED_SIZE -le 2000 ]; then
	echo "SQL_SIZE = $SQL_SIZE : FEED_SIZE = $FEED_SIZE: Failing out"
	logger -t db-refresh "SQL_SIZE = $SQL_SIZE : FEED_SIZE = $FEED_SIZE: Failing out"
	exit
fi
echo "Files sizes checked out ... copy them to build directory and exit"
echo "Globals"
cp $GLOBALS.xz /mnt/output/
echo "GVMDB"
cp $GVMDB.xz /mnt/output/
echo "Feeds"
cp $TAR.xz /mnt/output/
echo " !!! Done !!!"
rm /mnt/output/feed-update-running