#!/bin/bash 
set -Eeuo pipefail
echo "Ensure everything is linked properly"
echo "/usr/local/lib" > /etc/ld.so.conf.d/openvas.conf
ldconfig
