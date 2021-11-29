#!/bin/bash
tag=$1
if [ -z $tag ] ; then
	tag="latest"
else
	tag="$tag"
fi
case $1 in
	-t)
	shift
	tag=$1
	shift	
	;;
	-a)
	shift
	arch=$1
	shift
	;;
	*)
	echo " Specify at least the tag with -t"
	exit
	;;
esac
set -Eeuo pipefail
cd /home/scott/Projects/openvas/ovasbase
docker buildx build --push --no-cache --platform  linux/amd64,linux/arm64 -f Dockerfile -t immauss/ovasbase:latest .

cd ..

docker buildx build --push --no-cache --platform linux/amd64,linux/arm64 -f Dockerfile -t immauss/openvas:$tag .

docker rm -f $tag
docker pull immauss/openvas:$tag
docker run -d --name $tag immauss/openvas:$tag 
docker logs -f $tag

