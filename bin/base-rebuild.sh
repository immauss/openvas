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
PullArchives() {

	cp /var/lib/openvas/*.xz .
    if [ $(ls -l base.sql.xz | awk '{print $5}') -lt 1200 ]; then 
		echo "base.sql.xz size is invalid."
		exit 1
	fi 
    if [ $(ls -l var-lib.tar.xz | awk '{print $5}') -lt 1200 ]; then 
		echo "var-lib.tar.xz size is invalid."
		exit 1
	fi
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
	NOBASE=true
elif [ -z $arch ]; then
	#arch="linux/amd64,linux/arm64,linux/arm/v7"
	arch="linux/amd64,linux/arm64"
	ARM="true"
fi
# Make the version # in the image meta data consistent
# This will leave the 
if [ "$tag" != "latest" ] && [ "$tag" != "beta" ]; then
	echo $tag > ver.current
fi
VER=$(cat ver.current)
#

# Check to see if we need to pull the latest DB. 
# yes if it doesn't already exists
# Yes if the existing is < 7 days old.
echo "Checking Archive age"
if [ -f base.sql.xz ]; then
	DBAGE=$(expr $(date +%s) - $(stat $STAT var-lib.tar.xz) )
else
	PullArchives
fi
echo "Current archive age is: $DBAGE seconds"
if [ $DBAGE -gt 604800 ]; then
	PullArchives
fi
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
	echo "Starting container to build GSA" 
	    docker pull immauss/ovasbase
		docker run -it --rm \
			-v $(pwd)/ics-gsa:/ics-gsa \
			-v $(pwd)/tmp/build:/build \
			-v $(pwd):/build.d \
			-v $(pwd)/gsa-final:/final \
			immauss/ovasbase -c "cd /build.d; bash build.d/gsa-main.sh "
else
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
   --platform $arch -f Dockerfile --target slim -t immauss/openvas:${tag}-slim \
   -f $DOCKERFILE .
SLIMFIN=$(date +%s)



FINALSTART=$(date +%s)
docker buildx build $PUBLISH --platform $arch -f Dockerfile \
   --target final -t immauss/openvas:${tag} \
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
