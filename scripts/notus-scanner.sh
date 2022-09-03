#!/usr/bin/env bash

echo "Waiting for data"
sleep 10
while ! [ -d /var/lib/notus/products ]; do
	echo "Still waiting ..."
	sleep 1
done

echo "Starting the notus-scanner ...."
/usr/local/bin/notus-scanner \
	--products-directory /var/lib/notus/products \
	--log-file /var/log/gvm/notus-scanner.log \
	-b mosquitto \
	-p 1883 -f

