#!/usr/bin/env bash
set -Eeo pipefail

#Define  proper shutdown 
# This is only needed with the postgresql instance
cleanup() {
    echo "Container stopped, performing shutdown"
    su -c "/usr/lib/postgresql/13/bin/pg_ctl -D /data/database stop" postgres
}
# Clear out the old sockets so we can test for it in gvmd
if [ -S /run/postgresql/.s.PGSQL.5432 ]; then
	rm -f /run/postgresql/.s.PGSQL.5432
fi
# Until If find a better way, Force this here.
chown -R postgres /run/postgresql 

# Postgres config should be tighter.
# Actually, postgress should be in its own container!
# maybe redis should too. 
if [ ! -f "/setup" ]; then
	echo "Creating postgresql.conf and pg_hba.conf"
	# Need to look at restricting this. Maybe to localhost ?
	echo "listen_addresses = '*'" > /data/database/postgresql.conf
	echo "port = 5432" >> /data/database/postgresql.conf
	echo "log_destination = 'stderr'" >> /data/database/postgresql.conf
	echo "logging_collector = on" >> /data/database/postgresql.conf
	echo "log_directory = '/data/var-log/postgresql/'" >> /data/database/postgresql.conf
	echo "log_filename = 'postgresql-gvmd.log'" >> /data/database/postgresql.conf
	echo "log_file_mode = 0666" >> /data/database/postgresql.conf
	echo "log_truncate_on_rotation = off" >> /data/database/postgresql.conf
	echo "log_line_prefix = '%m [%p] %q%u@%d '" >> /data/database/postgresql.conf
	echo "log_timezone = 'Etc/UTC'" >> /data/database/postgresql.conf
	# This probably tooooo open.
	echo -e "host\tall\tall\t0.0.0.0/0\tmd5" > /data/database/pg_hba.conf
	echo -e "host\tall\tall\t::0/0\tmd5" >> /data/database/pg_hba.conf
	echo -e "local\tall\tall\ttrust"  >> /data/database/pg_hba.conf
	chown postgres:postgres -R /data/database
	touch /setup
fi

PGFAIL=0
PGUPFAIL=0
echo "Starting PostgreSQL..."
su -c "/usr/lib/postgresql/13/bin/pg_ctl -D /data/database start" postgres || PGFAIL=$?
echo "pg exit with $PGFAIL ." 
if [ $PGFAIL -ne 0 ]; then
        echo "It looks like postgres failed to start. ( Exit code: \"$?\" "
        echo "Assuming this is due to different database version and starting upgrade."
        /scripts/db-upgrade.sh || PGUPFAIL=$?
        if [ $PGUPFAIL -ne 0 ]; then
                echo "Looks like this is either not an upgrade problem, or the upgrade failed."
                exit
        else
                echo " DB Upgrade was a success. Starting postgresql 13"
                su -c "/usr/lib/postgresql/13/bin/pg_ctl -D /data/database start" postgres
        fi
fi

trap 'cleanup' SIGTERM
echo "Checking for existing DB"
su -c " psql -lqt " postgres
DB=$(su -c " psql -lqt" postgres | awk /gvmd/'{print $1}')
if [ "$DB" = "gvmd" ]; then
	LOADDEFAULT="false"
else
	LOADDEFAULT="true"
fi

# Pass this variable to gvmd via /run
echo $LOADDEFAULT > /run/loaddefault
#

# This is part of making sure we shutdown postgres properly on container shutdown and only needs to exist 
# in postgresql instance
#tail -f /var/log/postgresql/postgresql-13-main.log &
tail -f /data/var-log/postgresql/postgresql-gvmd.log &
wait $!
#wait $(ps axwu | awk /postgres.*postgres.-D/'{print $2}' |head -1)
