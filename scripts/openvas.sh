#!/usr/bin/env bash
set -Eeo pipefail
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
echo "Waiting for feeds"
until [ -d /data/var-lib/openvas/plugins/2024 ]; do
	echo  ". "
	sleep 5
done
echo -e "\n Sleeping an extra 30 seconds to ensure there are actually feeds in the directory." 
sleep 30
echo "Checking /var/lib/openvas"
if [ -d /var/lib/openvas ]; then
	echo "Linking to /var/lib/openvas"
	rm -rf /var/lib/openvas
	ln -s /data/var-lib/openvas /var/lib/openvas
fi

echo "Starting Open Scanner Protocol daemon for OpenVAS..."
/usr/local/bin/ospd-openvas --unix-socket /var/run/ospd/ospd-openvas.sock \
	--pid-file /run/ospd/ospd-openvas.pid \
	--log-file /usr/local/var/log/gvm/ospd-openvas.log \
	--lock-file-dir /var/lib/openvas \
	--socket-mode 0o777 \
	--mqtt-broker-address mosquitto \
	--mqtt-broker-port 1883 \
	--notus-feed-dir /var/lib/notus/advisories \
	--disable-notus-hashsum-verification true \
	-f

