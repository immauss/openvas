#!/bin/bash 
TAG=latest
VER=$(cat ver.current)
DOCKERFILE=$(mktemp)
sed "s/\$VER/$VER/" Dockerfile.refresh > $DOCKERFILE
docker buildx build -f $DOCKERFILE \
    --target final \
    -t gitlab.immauss.com:5050/immauss/openvas:latest \
    --platform linux/arm64,linux/amd64,linux/arm/v7 \
    --push .
