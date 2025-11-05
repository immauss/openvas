#!/bin/bash 

OLDTAG="latest"
STIME="300"
tag="mc-pg13"
BNDDIR="/tmp/$tag"
echo " Checking for bind dir $BNDDIR"
if [ -d $BNDDIR ]; then
	echo "Exists.... clearing"
	docker run -t --rm -v $BNDDIR:/mnt alpine sh -c "rm -vrf /mnt/*"
else
	echo "Creating $BNDDIR"
	mkdir -p $BNDDIR
fi

docker run  -d --rm -e SKIPSYNC=true -v $BNDDIR:/data --name $OLDTAG-bnd -p 8081:9392 immauss/openvas:$OLDTAG
# Wait for log entry to indicate the DB is in sync
echo "Sleeping for $STIME to make sure the feeds are updated in the db"
sleep $STIME
CONTINUE=0
COUNTER=0
while  [ $CONTINUE -eq 0 ] && [ $COUNTER -le 20 ]; do
        if docker logs $OLDTAG-bnd 2>&1 | grep -qs "update_nvt_cache_retry: rebuild successful"; then
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

docker stop $OLDTAG-bnd
docker rm -f $OLDTAG-bnd

# Clean up from any previous attempts
docker rm -f oldbnd-$tag

# Start new containers with new version of image and old version of data. 
docker run -d -v $BNDDIR:/data -p 9001:9392 --name oldbnd-$tag -e SKIPSYNC=true immauss/openvas:$tag

docker ps 

docker logs -fn 10 oldbnd-$tag
