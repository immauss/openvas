#!/bin/bash
set -Eeuo pipefail
cd /home/scott/Projects/openvas/ovasbase
docker build -f Dockerfile.buster -t immauss/ovasbase:buster .

cd ..

docker build -f Dockerfile.buster -t immauss/openvas:buster .

docker rm -f buster
docker run -d --name buster immauss/openvas:buster 
docker logs -f buster

