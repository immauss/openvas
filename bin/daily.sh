#!/bin/bash
# This script will run daily to update the data feeds.
# we'll first run the container in refresh mode, which will
# generate the archives
# then rebuild latest for both archs.
# The image will be pushed to the Immauss Registry Daily 
# and to docker hub bi-weekly
# This needs to call something (TBR) from ics-gsa to customize for gitlab.
set -Eeuo pipefail
StartTime=$(date +%s)
logger -t updater "Starting Data-Refresh"
cd /home/scott/Projects/openvas/Data-Refresh
docker compose up -d 
# Need to wait for the update to finish
echo "Waiting for the feeds to be updated"
sleep 30s
# This is create and removed by the feed-refresh.sh in the container.
while [ -f /home/scott/Projects/openvas/feed-update-running ]; do
    echo -n "."
    sleep 15m
    CurrentTime=$(date +%s)
    RunTime=$(($CurrentTime - $StartTime))
    if [ $RunTime -gt 10800 ]; then
        echo "3 hours have passed. Somethen went wrong."
        logger -t updater "Timeout of 3 hours exceeded. "
        docker compose stop
        exit
    fi
done
logger -t updater "Container run successful."
# if the day of the year is divisible by 14, then push to docker hub
# otherwise, only push to Immauss Registry
DOY=$(date +%j)
cd /home/scott/Projects/openvas/
if  [ $(($DOY % 14)) -eq 0 ]; then
    logger -t updater "Building images for DockerHub & Immauss"
    docker buildx build -t immauss/openvas:latest --platform amd64,arm64 -f Dockerfile.refresh .
    docker buildx build -t gitlab.immauss.com:5050/immauss/openvas:latest --platform amd64,arm64 -f Dockerfile.refresh .
else
    logger -t updater "Building images for Immauss"
    docker buildx build -t gitlab.immauss.com:5050/immauss/openvas:latest --platform amd64,arm64 -f Dockerfile.refresh .
fi

