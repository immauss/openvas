#!/bin/bash
set -Eeuo pipefail
# Source this for the latest release versions
. build.rc

echo "pip install of new greenbone-feed-sync"
python3 -m pip install greenbone-feed-sync 
