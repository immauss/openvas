#!/bin/bash 
TAG=latest
docker buildx build -f Dockerfile.refresh \
    --build-arg TAG=${TAG} --target final \
    -t gitlab.immauss.com/immauss/openvas:$TAG \
    --platform linux/arm64,linux/amd64,linux/arm/v7 \
    --push .