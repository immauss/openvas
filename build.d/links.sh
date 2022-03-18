#!/bin/bash
set -Eeuo pipefail
# Create openvas.conf for libs
echo "/usr/local/lib" > /etc/ld.so.conf.d/openvas.conf
ldconfig
