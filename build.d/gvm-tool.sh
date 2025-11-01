#!/bin/bash
set -Eeuo pipefail
# Source this for the latest release versions
. build.rc

echo "pip install GVM-tools"
python3 -m pip install --break-system-packages gvm-tools==$gvm_tools
