#!/usr/bin/env bash

# For this to work:
# 1. Need port 9390 open on container with gvmd
# 2. Need certs from said same gvmd instance.
# 3. archive with the certs must be mounted in /mnt/ and give as "-e CERTS="filename" on container start.
# 4. After starting this container, run the following on the master gvmd:
#    gvmd --verbose --create-scanner=“DEMO NAME”
#    –scanner-host=remote-host
#    –scanner-port=9390
#    –scanner-type=OSP-Sensor
#    –scanner-ca-pub=/var/lib/gvm/CA/cacert.pem
#    –scanner-key-pub=/var/lib/gvm/CA/clientcert.pem
#    –scanner-key-priv=/var/lib/gvm/private/CA/clientkey.pem

set -Eeuo pipefail
REDISDBS=${REDISDBS:-512}
CERTS=${CERTS:-fail}

 if [ -f /run/mosquittoup ]; then
    rm /run/mosquittoup
fi
 if [ -f /run/redisup ]; then
    rm /run/redisup
fi

if ! [ -d /var/lib/gvm/private ] && [ "$CERTS" == "fail" ]; then
    echo " You must specify an archive name for the certs."
    echo " Check the documentation on setting up the remote scanner."
    echo " Docs can be found at: https://github.com/immauss/openvas"
    exit
fi

if ! [ -d /var/lib/gvm/private/CA/cakey.pem ]; then
    cd /var/lib/gvm
    tar xvf /mnt/$CERTS
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


#  start Mosquitto


# Start the mqtt 
if  ! grep -qis  allow_anonymous /etc/mosquitto/mosquitto.conf; then  
        echo -e "listener 1883\nallow_anonymous true" >> /etc/mosquitto/mosquitto.conf
fi

chmod  777 /run/mosquitto
/usr/sbin/mosquitto -c /etc/mosquitto/mosquitto.conf  &

sleep 2
while ! [ -f /run/redisup ] && [ -f /run/mosquittoup ]; do
	echo "Waiting for redis & mosquitto"
	sleep 2
done

echo "Wait for redis socket to be created..."
while  [ ! -S /run/redis/redis.sock ]; do
	        sleep 1
done

if  ! grep -qis  mosquitto /etc/openvas/openvas.conf; then  
	echo "mqtt_server_uri = mosquitto:1883" |  tee -a /etc/openvas/openvas.conf
fi

# Extract the data feeds
if ! [ -f /var/lib/openvas/plugins/plugin_feed_info.inc ]; then
    cd /data
	echo "Unpacking base feeds data from /usr/lib/var-lib.tar.xz"
	tar xf /usr/lib/var-lib.tar.xz
	echo "Base DB and feeds collected on:"
	cat /data/var-lib/update.ts
fi


echo "Creating config"
echo "[OSPD - openvas]
port=9390
bind_address=0.0.0.0
log_level=INFO
ca_file=/var/lib/gvm/CA/cacert.pem
cert_file=/var/lib/gvm/CA/clientcert.pem
key_file=/var/lib/gvm/private/CA/clientkey.pem
pid_file=/run/ospd/ospd-openvas.pid
log_file=/var/log/gvm/ospd-openvas" > /etc/gvm/ospd-openvas.conf

echo "Starting Open Scanner Protocol daemon for OpenVAS..."
# /usr/local/bin/ospd-openvas --unix-socket /var/run/ospd/ospd-openvas.sock \
# 	--pid-file /run/ospd/ospd-openvas.pid \
# 	--log-file /usr/local/var/log/gvm/ospd-openvas.log \
# 	--lock-file-dir /var/lib/openvas \
# 	--socket-mode 0o777 \
# 	--mqtt-broker-address 127.0.0.1 \
# 	--mqtt-broker-port 1883 \
# 	--notus-feed-dir /var/lib/notus/advisories \
# 	-f
/usr/local/bin/ospd-openvas --config /etc/gvm/ospd-openvas.conf -f 
exit
gvmd --verbose --create-scanner=“DEMO NAME” \
--scanner-host=172.17.0.4 \
--scanner-port=9390 \
--scanner-type=OSP-Sensor \
--scanner-ca-pub=/var/lib/gvm/CA/cacert.pem \
--scanner-key-pub=/var/lib/gvm/CA/clientcert.pem \
--scanner-key-priv=/var/lib/gvm/private/CA/clientkey.pem