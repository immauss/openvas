#!/usr/bin/env bash
set -Eeo pipefail
# These are  needed for a first run WITH a new container image
# and an existing database in the mounted volume at /data
echo "Starting Open Scanner Protocol daemon for OpenVAS..."
exec ospd-openvas --log-file /usr/local/var/log/gvm/ospd-openvas.log \
             --unix-socket /run/ospd/ospd.sock --log-level INFO --socket-mode 777 -f



# We run ospd-openvas in the container as root. This way we don't need sudo.
# But if we leave the socket owned by root, gvmd can not communicate with it.
#chgrp gvm /run/ospd/ospd.sock
