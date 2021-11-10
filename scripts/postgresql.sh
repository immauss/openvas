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

if ! [ -d /var/log/postgresql ]; then
	
# Pass this variable to gvmd via /run
echo $LOADDEFAULT > /run/loaddefault
# These are  needed for a first run WITH a new container image
# and an existing database in the mounted volume at /data

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
