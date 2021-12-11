#!/bin/bash
set -Eeuo pipefail
# Source this for the latest release versions
echo "/usr/local/lib" > /etc/ld.so.conf.d/openvas.conf
ldconfig
