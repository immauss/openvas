#!/bin/bash
#
#Get current gvm versions
. build.rc
# Setup some variables
BUILDHOME=$(pwd)
STARTTIME=$(date +%s)
NOBASE="false"
RUNAFTER="1"
ARM="false"
ARMSTART=true
PRUNESTART=true
BASESTART=true
PUBLISH=" "
RUNOPTIONS=" "
GSABUILD="false"
OS=$(uname)
echo "OS is $OS"
if [ "$OS" == "Darwin" ]; then
	STAT="-f %a"
else
	STAT="-c %Y"
fi
echo "STAT is $STAT"
TimeMath() {
    local total_seconds="$1"
    local hours=$((total_seconds / 3600))
    local minutes=$(( (total_seconds % 3600) / 60 ))
    local seconds=$((total_seconds % 60))

    printf "%02d:%02d:%02d\n" "$hours" "$minutes" "$seconds"
}


while ! [ -z "$1" ]; do
  case $1 in
    -g)
	shift
	GSABUILD=true
	;;
	--push)
	shift
	PUBLISH="--push"
	GSABUILD=true
	NOBASE=true
	echo "Publishing to docker hub. Forcing GSA Build and NOBASE."
	;;
	--load)
	shift
	PUBLISH="--load"
	;;
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
	-B)
	shift
	FORCEBASE=true
	echo "Forcing ovasbase build"
	;;
	*)
        echo "I don't know what to do with $1 option"
	echo "Sorry ...."
	exit
	;;

  esac
done
if [ -z  $tag ]; then
	tag=latest
fi
echo "TAG $tag"
if [ "$tag" == "beta" ]; then
	echo "tag set to beta. Only building x86_64. and using local volume"
	arch="linux/amd64"
	PUBLISH="--load"
	RUNOPTIONS="--volume beta:/data"
	if [ "$FORCEBASE" == "true" ]; then
		NOBASE=false
		echo "Found FORCEBASE ... building ovasbase"
	else	
		NOBASE=true
	fi
elif [ -z $arch ]; then
	arch="linux/amd64,linux/arm64"
	ARM="true"
fi
# Make the version # in the image meta data consistent
# This will leave the 
if [ "$tag" != "latest" ] && [ "$tag" != "beta" ] && [ "$tag" != "test" ]; then
	echo $tag > ver.current
fi
VER=$(cat ver.current)
#


echo "Building with $tag and $arch"

set -Eeuo pipefail
if  [ "$NOBASE" == "false" ]; then
	echo "Building new ovasbase image"
	cd $BUILDHOME/ovasbase
	BASESTART=$(date +%s)
	# Always build all archs for ovasbase.
	#docker buildx build --push  --platform  linux/amd64,linux/arm64,linux/arm/v7 -f Dockerfile -t immauss/ovasbase  .
	docker buildx build --push  --platform  linux/amd64,linux/arm64 -f Dockerfile -t immauss/ovasbase:latest  .
	BASEFIN=$(date +%s)
	cd ..
fi
# First we build GSA using a single ovasbase x86_64 container. 
# this SIGNIFICANTLY speeds the builds.
# first check to see if the current version has been built already

if ! [ -f tmp/build/$gsa.tar.gz ] || [ "x$GSABUILD" == "xtrue" ] ; then 
  if [ "$(cat gsa-final/ver.current)" != "$tag" ] || [ "$tag" == "latest" ]; then
	echo "Starting container to build GSA" 
	    docker pull immauss/ovasbase
		docker run -it --rm \
			-v $(pwd)/ics-gsa:/ics-gsa \
			-v $(pwd)/tmp/build:/build \
			-v $(pwd):/build.d \
			-v $(pwd)/gsa-final:/final \
			-v $(pwd)/ver.current:/ver.current \
			immauss/ovasbase -c "cd /build.d; bash build.d/gsa-main.sh $tag"
		if [ $? -eq 0 ]; then
			cp -f ver.current gsa-final/	
		fi
  else
	echo "Looks like we have already built for $tag"
  fi
	echo "Looks like we have already built gsa $gsa"
fi
cd $BUILDHOME
# Use this to set the version in the Dockerfile.
# This should have worked with cmd line args, but does not .... :(
	DOCKERFILE=$(mktemp)
	sed "s/\$VER/$VER/" Dockerfile > $DOCKERFILE
#DOCKERFILE="Dockerfile"

# Now build everything together. At this point, this will normally only be the arm7 build as the amd64 was likely built and cached as beta.
SLIMSTART=$(date +%s)
docker buildx build $PUBLISH \
   --platform $arch -f Dockerfile \
   --target slim \
   -t immauss/openvas:${tag}-slim \
   -f $DOCKERFILE .
SLIMFIN=$(date +%s)



FINALSTART=$(date +%s)
docker buildx build $PUBLISH \
	--platform $arch \
   	--target final \
	-t immauss/openvas:${tag} \
   	-f $DOCKERFILE .
FINALFIN=$(date +%s)


#Clean up temp file
rm $DOCKERFILE

echo "Statistics:"
# First the dependent times
if ! [ $PRUNESTART ]; then
	PRUNE=$(expr $PRUNEFIN - $PRUNESTART)
	echo "Build Kit Cache flush: $(Timemath $PRUNE)" | tee timing
fi
if ! [ $BASESTART ]; then 
	BASE=$(expr $BASEFIN - $BASESTART )
	echo "ovasbase build time: $(TimeMath $BASE)" | tee -a timing
fi
if ! [ $ARMSTART ]; then
	ARM=$(expr $ARMFIN -$ARMSTART )
	echo "ARM64 Image build time: $(TimeMath $ARM)" | tee -a timing
fi
# These always run
SLIM=$(expr $SLIMFIN - $SLIMSTART )
FINAL=$(expr  $FINALFIN - $FINALSTART )
FULL=$(expr $FINALFIN - $STARTTIME )
echo "Slim Image build time: $(TimeMath $SLIM)" | tee -a timing
echo "Final Image build time: $(TimeMath $FINAL)" | tee -a timing
echo "Total run time: $(TimeMath $FULL)" | tee -a timing

if [ $RUNAFTER -eq 1 ]; then
	docker rm -f $tag
	# If the tag is beta, then we used --load locally, so no need to pull it. 
	if [ "$tag" != "beta" ]; then
		docker pull immauss/openvas:$tag
	fi
	docker run -d --name $tag -e SKIPSYNC=true -p 8080:9392 $RUNOPTIONS immauss/openvas:$tag 
	docker logs -f $tag
fi

# Update the versions in the Readme.md 
if [ "$PUBLISH" != " " ]; then
	echo "Updating Readme.md with current versions"
	# Readme Template
	READMETMP="templ.readme"
	# Current GB Versions
	VERSIONS="versions.md"
	# Use Perl for  editing
	perl -0777 -pe "{
		open(my \$fh, '<', '${VERSIONS}');
		local \$/;
		\$replacement = <\$fh>;
		s/XXXXXXXXXXXXX/\$replacement/g;
		}" "${READMETMP}" > Readme.md
	sed -i "s/XYXYXYXYXYX/$(cat ver.current)/" Readme.md
fi
