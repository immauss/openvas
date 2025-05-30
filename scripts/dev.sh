#!/bin/bash

REFRESH=${REFRESH:-false}
cd /gsa
if [ "$REFRESH" == "true" ]; then
    echo "Copying source from gsa.latest to gsa.dev"
    ls -l /gsa/gsa.latest
    cp -rvp gsa.latest/* gsa.dev/
    cd /gsa/gsa.dev
    ls -l
    npm install vite
else
    echo "Using existing code in gsa.dev"
fi

cd /gsa/gsa.dev/
npm run start  --host --fix
/bin/sh
#gsad --http-cors="http://127.0.0.1:8080"

