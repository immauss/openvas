#!/bin/bash
# Start the openvas -cantainer
 docker run -d -p 8080:9392 -e SKIPSYNC=true --name $1  immauss/openvas:$1 
 echo "Wait for openvas start up"
 COUNT=0
 while [ $COUNT -le 60 ]; do 
	 echo -n ". "
	 sleep 1
	 COUNT=$( expr $COUNT + 1 )
done
USERS=$( docker exec -u gvm fresh bash -c "gvmd --get-users ")
while [ "$USERS" != "admin" ]; do
	USERS=$( docker exec -u gvm fresh bash -c "gvmd --get-users ")
	echo "looking for gvmd"
	sleep 2
done
docker run -d --name scannable immauss/scannable
echo "Sleeping to give scanable a few seconds to start"
sleep 5
IP=$(docker logs scannable | awk /inet.172/'{ print $2 }' | sed -e "s/\/16//"  )
echo "Scannable IP is $IP"
echo "Create and start a scan of the scannable container"
docker exec -u gvm  $1  bash -c "gvm-script --gmp-password admin --gmp-username admin tls  ./scantest.py $IP  4a4717fe-57d2-11e1-9a26-406186ea4fc5" 

docker logs -f $1
