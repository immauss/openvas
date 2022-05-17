#!/bin/bash
# Create the volume and the bind dir from the old archive.
tag="mc-pg13"
OLDTAG="latest"
OLDVOL="test-$OLDTAG"
OLDBIND="$(pwd)/bind/testing/$OLDTAG"
OLDTAR="$OLDTAG-bind.tar.xz"

docker rm -f oldvol-$tag oldbind-$tag 
docker volume rm $OLDVOL
if [ -d $OLDBIND ]; then
	sudo rm -rf $(pwd)/bind/testing/$OLDTAG/* 
fi
docker run --rm -t -v $OLDBIND:/TO -v $(pwd)/bind:/FROM alpine sh -c \
	"cd /TO ;tar xvf /FROM/$OLDTAR --strip-components=7"
docker run --rm -t -v $OLDVOL:/TO -v $(pwd)/bind:/FROM alpine sh -c \
	"cd /TO ;tar xvf /FROM/$OLDTAR --strip-components=7"

# 
docker run -d -v $OLDVOL:/data -p 9001:9392 --name oldvol-$tag -e SKIPSYNC=true immauss/openvas:$tag
docker run -d -v $OLDBIND:/data -p 9002:9392 --name oldbind-$tag -e SKIPSYNC=true immauss/openvas:$tag


docker ps 
