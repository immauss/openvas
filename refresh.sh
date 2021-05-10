#!/bin/bash
# This script will refresh the data in the gvm-var-lib repo
# It will include a new db dump and the contents of /data/var-lib
# This should run from a cron with a long enough sleep to make sure
# the gvmd has updated the DB before creating the archive and pushing
# to github. It's probably not going to be useful to anyone but me
# but the output will benefit all. 
# Tag to work with. Normally latest but might be using new tag during upgrades.
TAG="21.04"
# Temp working directory ... needs enough space to pull the entire feed and then compress it. ~2G
TWD="/var/lib/openvas"
STIME="45m" # time between resync and archiving.
# Force a pull of the latest image.
docker pull immauss/openvas:$TAG
echo "Starting container for an update"
docker run -d --rm --name updater immauss/openvas:$TAG
date
echo "Sleeping for $STIME to make sure the feeds are updated in the db"
sleep $STIME

cd $TWD
echo "First copy the feeds from the container"
docker cp updater:/data/var-lib .
echo "Now dump the db from postgres"
docker exec -i updater su -c "/usr/lib/postgresql/12/bin/pg_dumpall" postgres > ./base.${TAG}.sql 

echo "Stopping update container"
docker stop updater

echo "Compress and archive the data"
tar cJf var-lib.tar.xz --exclude=var-lib/gvm/gvmd/gnupg var-lib
xz -1 base.sql
SQL_SIZE=$( ls -l base.sql.xz | awk '{print $5}')
FEED_SIZE=$( ls -l var-lib.tar.xz | awk '{print $5'})
if [ $SQL_SIZE -le 2000 ] || [ $FEED_SIZE -le 2000 ]; then
	logger -t db-refresh "SQL_SIZE = $SQL_SIZE : FEED_SIZE = $FEED_SIZE: Failing out"
	exit
fi

# Need error checking here to prevent pushing a nil DB.
scp *.xz push@www.immauss.com:/var/www/html/openvas/
if [ $? -ne 0 ]; then
	logger -t db-refresh "SCP of new db failed $?"
	exit
fi


# Force rebuild at docker hub.
git clone git+ssh://git@github.com/immauss/openvas.git
cd openvas

date > update.ts
git commit update.ts -m "Data update for $Date"
echo "And pushing to github"
git push 
echo "Cleaning up"
cd ..
rm -rf openvas var-lib *.xz
echo "All done"


