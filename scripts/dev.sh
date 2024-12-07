#!/bin/bash

REFRESH=${REFRESH:-false}
cd /gsa
if [ "$REFRESH" == "true" ]; then
    echo "Copying source from gsa.latest to gsa.dev"
    cp -rp gsa.latest/* gsa.dev/
else
    echo "Using existing code in gsa.dev"
fi

cd gsa.dev/
npm run start  --host --fix
/bin/sh
#gsad --http-cors="http://127.0.0.1:8080"

