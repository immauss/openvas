BRANCH=$(git branch | awk /\*/'{print $2}')
docker build -t immauss/openvas:$BRANCH .
if [ $? -ne 0 ]; then
	echo "Build failed. :("
	exit
fi
echo " Build complete. Starting test instance."
docker rm -f ${BRANCH}-test
docker run -d --name "${BRANCH}-test" -p 9000:9392 immauss/openvas:${BRANCH}
docker logs -f "${BRANCH}-test"
