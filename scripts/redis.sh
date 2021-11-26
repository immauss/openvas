#!/usr/bin/env bash
rm /run/redisup
set -Eeuo pipefail
USERNAME=${USERNAME:-admin}
PASSWORD=${PASSWORD:-admin}
RELAYHOST=${RELAYHOST:-172.17.0.1}
SMTPPORT=${SMTPPORT:-25}
REDISDBS=${REDISDBS:-512}
QUIET=${QUIET:-false}
# use this to rebuild the DB from scratch instead of using the one in the image.
NEWDB=${NEWDB:-false}
SKIPSYNC=${SKIPSYNC:-false}
RESTORE=${RESTORE:-false}
DEBUG=${DEBUG:-false}
HTTPS=${HTTPS:-false}
#GMP=${GMP:-9390}
GSATIMEOUT=${GSATIMEOUT:-15}
if [ "$DEBUG" == "true" ]; then
	for var in USERNAME PASSWORD RELAYHOST SMTPPORT REDISDBS QUIET NEWDB SKIPSYNC RESTORE DEBUG HTTPS GSATIMEOUT ; do 
		echo "$var = ${var}"
	done
fi

# Fire up redis
redis-server --unixsocket /run/redis/redis.sock --unixsocketperm 700 \
             --timeout 0 --databases $REDISDBS --maxclients 4096 --daemonize yes \
             --port 6379 --bind 127.0.0.1 --loglevel warning --logfile /data/var-log/gvm/redis-server.log

echo "Wait for redis socket to be created..."
while  [ ! -S /run/redis/redis.sock ]; do
        sleep 1
done

echo "Testing redis status..."
X="$(redis-cli -s /run/redis/redis.sock ping)"
while  [ "${X}" != "PONG" ]; do
        echo "Redis not yet ready..."
        sleep 1
        X="$(redis-cli -s /run/redis/redis.sock ping)"
done
echo "Redis ready."
touch /run/redisup

echo "++++++++++++++++"
echo "+ Tailing logs +"
echo "++++++++++++++++"
tail -F /data/var-log/gvm/redis-server.log
