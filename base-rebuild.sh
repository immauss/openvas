#!/bin/bash
set -Eeuo pipefail
cd /home/scott/Projects/openvas/ovasbase
docker buildx build --push --platform linux/arm/v7 -t immauss/ovasbase:armv7 .

cd ..

docker buildx build --push --no-cache --platform linux/arm/v7 -t immauss/openvas:armv7 .

