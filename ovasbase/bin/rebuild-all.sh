#!/bin/bash
tag=$1
if [ -z $tag ] ; then
        tag="latest"
else
        tag="$tag"
fi
docker buildx build -t immauss/ovasbase:$tag --platform linux/arm64,linux/amd64,linux/arm/v7 --push  .
#docker buildx build -t immauss/ovasbase:$tag --platform linux/arm64,linux/amd64 --push  .
