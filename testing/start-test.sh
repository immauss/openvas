#!/bin/bash
# Create the volume and the bind dir from the old archive.
tag="mc-pg13"
OLDTAG="latest"
OLDVOL="test-$OLDTAG"
OLDBIND="$(pwd)/bind/testing/$OLDTAG"
OLDTAR="$OLDTAG-bind.tar.xz"

# Clean up from any previous attempts
docker rm -f oldvol-$tag oldbind-$tag 
docker volume rm $OLDVOL
if [ -d $OLDBIND ]; then
	sudo rm -rf ${OLDBIND}/* 
fi
# Use alpine to mount the bind dir and vol for old version data and populate from archive create previously.
docker run --rm -t -v $OLDBIND:/TO -v $(pwd)/archive:/FROM alpine sh -c \
	"cd /TO ;tar xvf /FROM/$OLDTAR --strip-components=3"
docker run --rm -t -v $OLDVOL:/TO -v $(pwd)/archive:/FROM alpine sh -c \
	"cd /TO ;tar xvf /FROM/$OLDTAR --strip-components=3"

# Start new containers with new version of image and old version of data. 
docker run -d -v $OLDVOL:/data -p 9001:9392 --name oldvol-$tag -e SKIPSYNC=true immauss/openvas:$tag
docker run -d -v $OLDBIND:/data -p 9002:9392 --name oldbind-$tag -e SKIPSYNC=true immauss/openvas:$tag


docker ps 

echo "Now check logs from both containers for errors. "

