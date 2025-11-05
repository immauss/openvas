#!/bin/bash 
# this is used to create an archive to popoluate a volume or bind directory for update testing.
# 1. Create directory 
# 2. Start a nosync container to build the DB
# 3. Execute a script to add host, credentials, and create a task
# 4. Stop container
# 5. Create an archive of the bind dir 
# - Testing processes will use the  archives to create new vol/bind for testing 

OLDTAG="latest"
STIME="300"
# we need one with a bind 
if ! [ -d ./bind/$OLDTAG-bind ]; then
	mkdir -p  ./bind/$OLDTAG-bind
fi
docker run  -d --rm -e SKIPSYNC=true -v $(pwd)/bind/$OLDTAG-bind:/data --name $OLDTAG-bind -p 8081:9392 immauss/openvas:$OLDTAG
# Wait for log entry to indicate the DB is in sync
echo "Sleeping for $STIME to make sure the feeds are updated in the db"
sleep $STIME
CONTINUE=0
COUNTER=0
while  [ $CONTINUE -eq 0 ] && [ $COUNTER -le 20 ]; do
        if docker logs $OLDTAG-bind 2>&1 | grep -qs "update_nvt_cache_retry: rebuild successful"; then
                CONTINUE=1
                echo "looks like it's done"
        else
                echo "Not done yet."
        fi
        COUNTER=$( expr $COUNTER + 1)
        sleep 1m
done

# Execute script to build needed data

echo " Run some k00l c0de here "

# Stop containers

docker stop $OLDTAG-bind

# Create archives

sudo tar cJvf ./archive/$OLDTAG-bind.tar.xz ./bind/$OLDTAG-bind

echo " All Done"
ls -l ./archive/

# End

