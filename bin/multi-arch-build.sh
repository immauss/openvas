#!/bin/bash
PLATFORMS="linux/arm/v7 linux/arm64"
for platform in $PLATFORMS; do
	echo "############################## $platform ######################"
	docker buildx build --platform $platform -t $platform --load .
done

docker buildx build --platform linux/arm64,linux/amd64,linux/arm/v7 --push -t immauss/openvas:21.04.03 . 
