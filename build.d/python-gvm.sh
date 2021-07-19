#!/bin/bash
set -Eeuo pipefail
# Source this for the latest release versions
. build.rc
python3 -m pip install python-gvm==$python_gvm
