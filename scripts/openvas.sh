#!/usr/bin/env bash
set -Eeo pipefail
sleep 2
while ! [ -f /run/redisup ]; do
	echo "Waiting for redis"
	sleep 2
done
echo "Starting Open Scanner Protocol daemon for OpenVAS..."
exec ospd-openvas --log-file /usr/local/var/log/gvm/ospd-openvas.log \
             --unix-socket /run/ospd/ospd.sock --log-level INFO --socket-mode 777 -f



