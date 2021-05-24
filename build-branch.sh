BRANCH=$(git branch | awk /\*/'{print $2}')
docker build -t immauss/openvas:$BRANCH . 2>&1 | tee build.log
echo " Build complete. Starting test instance."
docker rm -f ${BRANCH}-test
docker run -d -p 9392:9000 --name "${BRANCH}-test" immauss/openvas:${BRANCH}
docker logs -f "${BRANCH}-test"
