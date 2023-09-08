#!/bin/bash
STARTTIME=$(date +%s)
NOBASE="false"
RUNAFTER="1"
ARM="false"
ARMSTART=true
PRUNESTART=true
BASESTART=true
TimeMath() {
    local total_seconds="$1"
    local hours=$((total_seconds / 3600))
    local minutes=$(( (total_seconds % 3600) / 60 ))
    local seconds=$((total_seconds % 60))

    printf "%02d:%02d:%02d\n" "$hours" "$minutes" "$seconds"
}
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
	PRUNESTART=$(date +%s)
	docker buildx prune -af 
	PRUNEFIN=$(date +%s)
	shift
	;;
	-N)
	shift
	NOBASE=true;
	echo "Skipping ovasbase build"
	;;
	-n)
	shift
	RUNAFTER=0
	echo "OK, we'll skip running the image after build"
	;;
  esac
done
if [ -z  $tag ]; then
	tag=latest
fi
echo "TAG $tag"
if [ "$tag" == "beta" ]; then
	echo "tag set to beta. Only building x86_64."
	arch="linux/amd64"
elif [ -z $arch ]; then
	arch="linux/amd64,linux/arm64,linux/arm/v7"
	ARM="true"
fi

echo "Building with $tag and $arch"
set -Eeuo pipefail
if  [ "$NOBASE" == "false" ]; then
	cd /home/scott/Projects/openvas/ovasbase
	BASESTART=$(date +%s)
	docker buildx build --push  --platform  linux/amd64,linux/arm64,linux/arm/v7 -f Dockerfile -t immauss/ovasbase  .
	BASEFIN=$(date +%s)
	cd ..
fi
cd /home/scott/Projects/openvas
# Use this to set the version in the Dockerfile.
# This hould have worked with cmd line args, but does not .... :(
	DOCKERFILE=$(mktemp)
	sed "s/\$VER/$tag/" Dockerfile > $DOCKERFILE
# Because the arm64 build seems to always fail when building a the same time as the other archs ....
# We'll build it first to have it cached for the final build. But we only need the slim
#
if [ "$ARM" == "true" ]; then
	ARM64START=$(date +%s)
	docker buildx build --build-arg TAG=${tag} --push \
	   --platform linux/arm64 -f Dockerfile --target slim -t immauss/openvas:${tag}-slim \
	   -f $DOCKERFILE .
	ARM64FIN=$(date +%s)
fi
# Now build everything together. At this point, this will normally only be the arm7 build as the amd64 was likely built and cached as beta.
SLIMSTART=$(date +%s)
docker buildx build --build-arg TAG=${tag} --push \
   --platform $arch -f Dockerfile --target slim -t immauss/openvas:${tag}-slim \
   -f $DOCKERFILE .
SLIMFIN=$(date +%s)
FINALSTART=$(date +%s)
docker buildx build --build-arg TAG=${tag} --push --platform $arch -f Dockerfile \
   --target final -t immauss/openvas:${tag} \
   -f $DOCKERFILE .
FINALFIN=$(date +%s)

#Clean up temp file
rm $DOCKERFILE

echo "Statistics:"
# First the dependent times.
if ! [ $PRUNESTART ]; then
	PRUNE=$(expr $PRUNEFIN - $PRUNESTART)
	echo "Build Kit Cache flush: $(Timemath $PRUNE)"
fi
if ! [ $BASESTART ]; then 
	BASE=$(expr $BASEFIN - $BASESTART )
	echo "ovasbase build time: $(TimeMath $BASE)"
fi
if ! [ $ARMSTART ]; then
	ARM=$(expr $ARMFIN -$ARMSTART )
	echo "ARM64 Image build time: $(TimeMath $ARM)"
fi
# These always run
SLIM=$(expr $SLIMFIN - $SLIMSTART )
FINAL=$(expr  $FINALFIN - $FINALSTART )
FULL=$(expr $FINALFIN - $STARTTIME )
echo "Slim Image build time: $(TimeMath $SLIM)"
echo "Final Image build time: $(TimeMath $FINAL)"
echo "Total run time: $(TimeMath $FULL)"

if [ $RUNAFTER -eq 1 ]; then
	docker rm -f $tag
	docker pull immauss/openvas:$tag
	docker run -d --name $tag -e SKIPSYNC=true -p 8080:9392 immauss/openvas:$tag 
	docker logs -f $tag
fi
