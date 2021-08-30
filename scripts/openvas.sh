#!/usr/bin/env bash
set -Eeuo pipefail

echo "Starting Open Scanner Protocol daemon for OpenVAS..."
ospd-openvas --log-file /usr/local/var/log/gvm/ospd-openvas.log \
             --unix-socket /run/ospd/ospd.sock --log-level INFO --socket-mode 777


# wait for ospd to start by looking for the socket creation.
while  [ ! -S /run/ospd/ospd.sock ]; do
	sleep 1
done

# We run ospd-openvas in the container as root. This way we don't need sudo.
# But if we leave the socket owned by root, gvmd can not communicate with it.
chgrp gvm /run/ospd/ospd.sock

wait $!