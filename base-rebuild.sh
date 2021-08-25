#!/bin/bash
tag=armv7
set -Eeuo pipefail
cd /home/scott/Projects/openvas/ovasbase
docker buildx build --push --no-cache --platform linux/arm/v7 -f Dockerfile -t immauss/ovasbase:$tag .

cd ..

docker buildx build --push --no-cache --platform linux/arm/v7 -f Dockerfile -t immauss/openvas:$tag .

docker rm -f $tag
docker pull immauss/openvas:$tag
docker run -d --name $tag immauss/openvas:$tag 
docker logs -f $tag

