#!/bin/bash
# Create the volume and the bind dir from the old archive.
tag="master"
OLDTAG="21.4.3"
OLDVOL="test-$OLDTAG"
OLDBIND="/bind/testing/$OLDTAG"
OLDTAR="$OLDTAG-bind.tar.xz"

docker rm -f oldvol-$tag oldbind-$tag 
docker volume rm $OLDVOL
if [ -d $OLDBIND ]; then
	sudo rm -rf /bind/testing/$OLDTAG/* 
fi
docker run --rm -t -v $OLDBIND:/TO -v /bind:/FROM alpine sh -c \
	"cd /TO ;tar xvf /FROM/$OLDTAR --strip-components=2"
docker run --rm -t -v $OLDVOL:/TO -v /bind:/FROM alpine sh -c \
	"cd /TO ;tar xvf /FROM/$OLDTAR --strip-components=2"

# 
docker run -d -v $OLDVOL:/data -p 9001:9392 --name oldvol-$tag -e SKIPSYNC=true immauss/openvas:$tag
docker run -d -v $OLDBIND:/data -p 9002:9392 --name oldbind-$tag -e SKIPSYNC=true immauss/openvas:$tag


docker ps 
