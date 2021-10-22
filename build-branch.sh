BRANCH=$(git branch | awk /\*/'{print $2}')
docker buildx build --no-cache --platform linux/amd64 -t immauss/openvas:$BRANCH --load .
if [ $? -ne 0 ]; then
	echo "Build failed. :("
	exit
fi
echo " Build complete. Starting test instance."
docker rm -f ${BRANCH}-test
docker run -d --name "${BRANCH}-test" -e SKIPSYNC=true -p 9000:9392 immauss/openvas:${BRANCH}
docker logs -f "${BRANCH}-test"
