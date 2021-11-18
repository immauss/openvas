if [ -z $1 ]; then
	OPT=" "
else
	OPT="$@"
fi
BRANCH=$(git branch | awk /\*/'{print $2}')
docker buildx build $OPT --platform linux/amd64 -t immauss/openvas:$BRANCH --load .
if [ $? -ne 0 ]; then
	echo "Build failed. :("
	exit
fi
echo " Build complete. Starting test instance."
cd multi-container
docker-compose -d up 
sleep 10
docker ps --all
