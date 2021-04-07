BRANCH=$(git branch | awk /\*/'{print $2}')
docker build -t immauss/openvas:$BRANCH .
echo " Build complete. Starting test instance."
docker run -d --name "${BRANCH}-test" immauss/openvas:${BRANCH}
docker logs -f "${BRANCH}-test"
