#!/bin/bash 

OLDTAG="latest"
STIME="300"
tag="mc-pg13"

docker volume rm $OLDTAG-vol 
docker run  -d --rm -e SKIPSYNC=true -v $OLDTAG-vol:/data --name $OLDTAG-vol -p 8081:9392 immauss/openvas:$OLDTAG
# Wait for log entry to indicate the DB is in sync
echo "Sleeping for $STIME to make sure the feeds are updated in the db"
sleep $STIME
CONTINUE=0
COUNTER=0
while  [ $CONTINUE -eq 0 ] && [ $COUNTER -le 20 ]; do
        if docker logs $OLDTAG-vol 2>&1 | grep -qs "update_nvt_cache_retry: rebuild successful"; then
                CONTINUE=1
                echo "looks like it's done"
        else
                echo "Not done yet. $COUNTER"
        fi
        COUNTER=$( expr $COUNTER + 1)
        sleep 1m
done

# Execute script to build needed data

echo " Run some k00l c0de here "

# Stop containers

docker stop $OLDTAG-vol
docker rm -f $OLDTAG-vol

# Clean up from any previous attempts
docker rm -f oldvol-$tag

# Start new containers with new version of image and old version of data. 
docker run -d -v $OLDTAG-vol:/data -p 9001:9392 --name oldvol-$tag -e SKIPSYNC=true immauss/openvas:$tag

docker ps 

docker logs -fn 10 
