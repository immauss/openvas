#!/bin/bash
tag=$1
if [ -z $1 ] ; then
	echo "options ?"
	exit
fi
while ! [ -z "$1" ]; do
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
done
if [ -z  $tag ]; then
	tag=latest
fi
if [ -z $arch ]; then
	arch="linux/amd64,linux/arm64"
fi

echo "Building with $tag and $arch"
set -Eeuo pipefail
cd /home/scott/Projects/openvas/ovasbase
docker buildx build --push --no-cache --platform  $arch -f Dockerfile -t immauss/ovasbase:latest  .

cd ..

docker buildx build --push --no-cache --platform $arch -f Dockerfile -t immauss/openvas:$tag .

docker rm -f $tag
docker pull immauss/openvas:$tag
docker run -d --name $tag immauss/openvas:$tag 
docker logs -f $tag

