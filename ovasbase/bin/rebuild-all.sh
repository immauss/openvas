#!/bin/bash
tag=$1
if [ -z $tag ] ; then
        tag="latest"
else
        tag="$tag"
fi
docker buildx build -t immauss/openvas:$tag --platform linux/arm64,linux/amd64 --push  .
