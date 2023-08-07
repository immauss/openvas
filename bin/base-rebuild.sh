#!/bin/bash
NOBASE="false"
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
	-p)
	echo " Flushing build kit cache"
	docker buildx prune -af 
	shift
	;;
	-N)
	shift
	NOBASE=true;
	echo "Skipping ovasbase build"
	;;
  esac
done
if [ -z  $tag ]; then
	tag=latest
fi
echo "TAG $tag"
if [ "$tag" == "beta" ]; then
	arch="linux/amd64,linux/arm64,linux/arm/v7"
elif [ -z $arch ]; then
	echo "tag set to beta. Only building x86_64."
	arch="linux/amd64"
fi

echo "Building with $tag and $arch"
set -Eeuo pipefail
if  [ "$NOBASE" == "false" ]; then
	cd /home/scott/Projects/openvas/ovasbase
	docker buildx build --push  --platform  $arch -f Dockerfile -t immauss/ovasbase  .
	cd ..
fi
cd /home/scott/Projects/openvas
docker buildx build --build-arg TAG=${tag} --push --platform $arch -f Dockerfile --target slim -t immauss/openvas:${tag}-slim .
docker buildx build --build-arg TAG=${tag} --push --platform $arch -f Dockerfile --target final -t immauss/openvas:${tag} .
docker rm -f $tag
docker pull immauss/openvas:$tag
docker run -d --name $tag -e SKIPSYNC=true -p 8080:9392 immauss/openvas:$tag 
docker logs -f $tag

