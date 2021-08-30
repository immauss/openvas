#!/usr/bin/env bash
#set -Eeuo pipefail
set -Eeo pipefail
#Define  proper shutdown 
# This is only needed with the postgresql instance
cleanup() {
    echo "Container stopped, performing shutdown"
    su -c "/usr/lib/postgresql/12/bin/pg_ctl -D /data/database stop" postgres
}

trap 'cleanup' SIGTERM
# Clear out the old sockets so we can test for it in gvmd
if [ -S /run/postgresql/.s.PGSQL.5432 ]; then
	rm -f /run/postgresql/.s.PGSQL.5432
fi

# This is for a first run with no existing database.
# Also determins if we are loading the default DB. The assumption here
# is that if we just created an empty DB, then we want to load the baseDB into it. 
# the "NEWDB" flag on start should be used to overide the loading of the basedb and 
# force gvmd to create a "new database" from scratch by pulling from the feeds.
if  [ ! -d /data/database ]; then
	mkdir -p /data/database
	echo "Creating Data and database folder..."
	mv /var/lib/postgresql/12/main/* /data/database
	ln -s /data/database /var/lib/postgresql/12/main
	chown postgres:postgres -R /data/database
	chmod 700 /data/database
	LOADDEFAULT="true"
else
	LOADDEFAULT="false"
fi

# Pass this variable to gvmd via /run
echo $LOADDEFAULT > /run/loaddefault
# These are  needed for a first run WITH a new container image
# and an existing database in the mounted volume at /data

if [ ! -L /var/lib/postgresql/12/main ]; then
	echo "Fixing Database folder..."
	rm -rf /var/lib/postgresql/12/main
	ln -s /data/database /var/lib/postgresql/12/main
	chown postgres:postgres -R /data/database
fi
if [ ! -d /usr/local/var/lib ]; then
	mkdir -p /usr/local/var/lib/gsm
	mkdir -p /usr/local/var/lib/openvas
	mkdir -p /usr/local/var/log/gvm
fi
if [ ! -L /usr/local/var/lib  ]; then
	echo "Fixing local/var/lib ... "
	if [ ! -d /data/var-lib ]; then
		mkdir /data/var-lib
	fi
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

if [ ! -L /usr/local/var/log/gvm ]; then
	echo "Fixing log directory for persistent logs .... "
	if [ ! -d /data/var-log/ ]; then mkdir /data/var-log; fi
	#cp -rf /usr/local/var/log/gvm/* /data/var-log/ 
	rm -rf /usr/local/var/log/gvm
	ln -s /data/var-log /usr/local/var/log/gvm 
	chown gvm /data/var-log
fi


# Postgres config should be tighter.
# Actually, postgress should be in its own container!
# maybe redis should too. 
if [ ! -f "/setup" ]; then
	echo "Creating postgresql.conf and pg_hba.conf"
	# Need to look at restricting this. Maybe to localhost ?
	echo "listen_addresses = '*'" >> /data/database/postgresql.conf
	echo "port = 5432" >> /data/database/postgresql.conf
	# This probably tooooo open.
	echo -e "host\tall\tall\t0.0.0.0/0\ttrust" >> /data/database/pg_hba.conf
	echo -e "host\tall\tall\t::0/0\ttrust" >> /data/database/pg_hba.conf
	echo -e "local\tall\tall\ttrust"  >> /data/database/pg_hba.conf
	chown postgres:postgres -R /data/database
fi

echo "Starting PostgreSQL..."
su -c "/usr/lib/postgresql/12/bin/pg_ctl  -D /data/database start" postgres

# This is part of making sure we shutdown postgres properly on container shutdown and only needs to exist 
# in postgresql instance
tail -f /var/log/postgresql/postgresql-12-main.log &
wait $!
