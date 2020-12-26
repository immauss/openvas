#!/usr/bin/env bash
set -Eeuo pipefail

USERNAME=${USERNAME:-admin}
PASSWORD=${PASSWORD:-admin}
RELAYHOST=${RELAYHOST:-172.17.0.1}
SMTPPORT=${SMTPPORT:-25}
REDISDBS=${REDISDBS:-128}


echo "Setup / Fix the /usr/local/var/run"
#if [ -d /usr/local/var/run ]; then
	#echo "linking to '/run'"
	#rm -rf /usr/local/var/run
	#ln -s /run /usr/local/var/run
	#chmod 777 /run
#else
	#echo "already linked to '/run'"
#fi
chmod 777 /usr/local/var/run

if [ ! -d "/run/redis" ]; then
	mkdir /run/redis
fi
if  [ -S /run/redis/redis.sock ]; then
        rm /run/redis/redis.sock
fi
redis-server --unixsocket /run/redis/redis.sock --unixsocketperm 700 --timeout 0 --databases $REDISDBS --maxclients 512 --daemonize yes --port 6379 --bind 0.0.0.0

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


if  [ ! -d /data ]; then
	echo "Creating Data folder..."
        mkdir /data
fi

if  [ ! -d /data/database ]; then
	echo "Creating Database folder..."
	mv /var/lib/postgresql/10/main /data/database
	ln -s /data/database /var/lib/postgresql/10/main
	chown postgres:postgres -R /var/lib/postgresql/10/main
	chown postgres:postgres -R /data/database
fi

if [ ! -L /var/lib/postgresql/10/main ]; then
	echo "Fixing Database folder..."
	rm -rf /var/lib/postgresql/10/main
	ln -s /data/database /var/lib/postgresql/10/main
	chown postgres:postgres -R /var/lib/postgresql/10/main
	chown postgres:postgres -R /data/database
fi

if [ ! -L /usr/local/var/lib  ]; then
	echo "Fixing local/var/lib ... "
	if [ ! -d /data/var-lib ]; then  mkdir /data/var-lib; fi
	cp -rf /usr/local/var/lib/* /data/var-lib
	rm -rf /usr/local/var/lib
	ln -s /data/var-lib /usr/local/var/lib
fi
if [ ! -L /usr/local/share ]; then
	echo "Fixing local/share ... "
	if [ ! -d /data/local-share ]; then mkdir /data/local-share; fi
	cp -rf /usr/local/share/* /data/local-share/
	rm -rf /usr/local/share 
	ln -s /data/local-share /usr/local/share 
fi

echo "Starting PostgreSQL..."
/usr/bin/pg_ctlcluster --skip-systemctl-redirect 10 main start

if [ ! -f "/firstrun" ]; then
	echo "Running first start configuration..."

	echo "Creating Openvas NVT sync user..."
	useradd --home-dir /usr/local/share/openvas openvas-sync
	chown openvas-sync:openvas-sync -R /usr/local/share/openvas
	chown openvas-sync:openvas-sync -R /usr/local/var/lib/openvas
	echo "Creating Greenbone Vulnerability system user..."
	useradd --home-dir /usr/local/share/gvm gvm
	echo "umask 0002" >> /usr/local/share/.profile
	chown gvm:gvm -R /usr/local/share/gvm
	if [ ! -d /usr/local/var/lib/gvm/cert-data ]; then mkdir -p /usr/local/var/lib/gvm/cert-data; fi
	chown gvm:gvm -R /usr/local/var/lib/gvm
	chmod 770 -R /usr/local/var/lib/gvm
	chown gvm:gvm -R /usr/local/var/log/gvm
	chown gvm:gvm -R /usr/local/var/run
	adduser openvas-sync gvm
	adduser gvm openvas-sync
	touch /firstrun
fi

if [ ! -f "/data/firstrun" ]; then
	echo "Creating Greenbone Vulnerability Manager database"
	su -c "createuser -DRS gvm" postgres
	su -c "createdb -O gvm gvmd" postgres
	su -c "psql --dbname=gvmd --command='create role dba with superuser noinherit;'" postgres
	su -c "psql --dbname=gvmd --command='grant dba to gvm;'" postgres
	su -c "psql --dbname=gvmd --command='create extension \"uuid-ossp\";'" postgres
	su -c "psql --dbname=gvmd --command='create extension \"pgcrypto\";'" postgres
	touch /data/firstrun
fi

#sleep 1d
echo "Updating NVTs and other data"
echo "This could take a while if you are not using persistent storage for your NVTs"
echo " or this is the first time pulling to your persistent storage."
echo " the time will be mostly dependent on your available bandwidth."
echo " We sleep for 5 seconds between sync command to make sure everything closes"
echo " and it doesnt' look like we are connecting more than once."
# Fix perms on var/run for the sync to function
chmod 777 /usr/local/var/run/
# And it should be empty. (Thanks felimwhiteley )
if [ -f /usr/local/var/run/feed-update.lock ]; then
        # If NVT updater crashes it does not clear this up without intervention
        echo "Removing feed-update.lock"
	rm /usr/local/var/run/feed-update.lock
fi
echo " Pulling NVTs from greenbone" 
su -c "/usr/local/bin/greenbone-nvt-sync" openvas-sync
sleep 5
echo " Pulling cert-data from greenbone"
su -c "/usr/local/sbin/greenbone-certdata-sync" openvas-sync
sleep 5
echo " Pulling scapdata from greenboon"
su -c "/usr/local/sbin/greenbone-scapdata-sync" openvas-sync 

if [ -f /var/run/ospd.pid ]; then
  rm /var/run/ospd.pid
fi

if [ -S /tmp/ospd.sock ]; then
  rm /tmp/ospd.sock
fi
echo "Starting Postfix for report delivery by email"
# Configure postfix
sed -i "s/^relayhost.*$/relayhost = ${RELAYHOST}:${SMTPPORT}/" /etc/postfix/main.cf
# Start the postfix  bits
#/usr/lib/postfix/sbin/master -w
service postfix start


echo "Starting Open Scanner Protocol daemon for OpenVAS..."
ospd-openvas --log-file /usr/local/var/log/gvm/ospd-openvas.log --unix-socket /tmp/ospd.sock --log-level INFO

# wait for ospd to start by looking for the socket creation.
while  [ ! -S /tmp/ospd.sock ]; do
	sleep 1
done

# This is cludgy and needs a better fix. namely figure out how to hard code alllll of the scoket references in the startup process.
# It's possible this is a problem with my DB as I only see it when using my DB. 
if [ ! -L /var/run/openvassd.sock ]; then
	echo "Fixing the ospd socket ..."
	rm -f /var/run/openvassd.sock
	ln -s /tmp/ospd.sock /var/run/openvassd.sock
fi

chmod 666 /tmp/ospd.sock
echo "Migrating database if needed"
su -c "gvmd -m" gvm
echo "Starting Greenbone Vulnerability Manager..."
su -c "gvmd --osp-vt-update=/tmp/ospd.sock" gvm

if [ ! -L /var/run/gvmd.sock ]; then
	echo "Fixing the gvmd socket ..."
	rm -f /var/run/gvmd.sock
	ln -s /usr/local/var/run/gvmd.sock /var/run/gvmd.sock
fi

until su -c "gvmd --get-users" gvm; do
	sleep 1
done

if [ ! -f "/data/created_gvm_user" ]; then
	echo "Creating Greenbone Vulnerability Manager admin user"
	su -c "gvmd --create-user=${USERNAME} --password=${PASSWORD}" gvm
	
	touch /data/created_gvm_user
fi

echo "Starting Greenbone Security Assistant..."
su -c "gsad --verbose --http-only --no-redirect --port=9392" gvm

echo "++++++++++++++++++++++++++++++++++++++++++++++"
echo "+ Your GVM 11 container is now ready to use! +"
echo "++++++++++++++++++++++++++++++++++++++++++++++"
echo ""
echo "++++++++++++++++"
echo "+ Tailing logs +"
echo "++++++++++++++++"
tail -F /usr/local/var/log/gvm/*
