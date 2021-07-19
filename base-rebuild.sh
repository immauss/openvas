#!/bin/bash
set -Eeuo pipefail
cd /home/scott/Projects/openvas/ovasbase
docker buildx build --push --platform linux/amd64,linux/arm64 -f Dockerfile.buster -t immauss/ovasbase:buster .

cd ..

docker buildx build --push --no-cache --platform linux/amd64,linux/arm64 -f Dockerfile.buster -t immauss/openvas:buster .

docker rm -f buster
docker pull immauss/openvas:buster
docker run -d --name buster immauss/openvas:buster 
docker logs -f buster

