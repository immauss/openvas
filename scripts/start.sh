#!/usr/bin/env bash
set -Eeuo pipefail
#Define  proper shutdown 
cleanup() {
    echo "Container stopped, performing shutdown"
    su -c "/usr/lib/postgresql/12/bin/pg_ctl -D /data/database stop" postgres
}

#Trap SIGTERM
trap 'cleanup' SIGTERM

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

function DBCheck {
        DB=$(su -c " psql -lqt" postgres | awk /gvmd/'{print $1}')
        if [ "$DB" = "gvmd" ]; then
		echo 1
	else
		echo 0
        fi
}
# First, we need to setup the filesystem properly.
# Tried to do this in the base image, but it breaks too manythings 
# Primarily with bind vs docker volumes for storage
# But my efforts did yield a nice script to handle it all
if ! [ -f /.fs-setup-complete ]; then
	/fs-setup.sh 
fi
# Need something new here to check for existing 'old' /data and fix all the links.
# maybe an option passed to fs-setup?

# 21.4.4-01 and up uses a slightly different structure on /data, so we look for the old, and correct if we find it. 
if [ -f /data/var-log/gvmd.log ]; then
	echo " Correcting Volume dir structure"
	mkdir -p /data/var-log/gvm
	mv /data/var-log/*.log /data/var-log/gvm
	chown -R gvm:gvm /data/var-log/gvm 
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

# Postgres config should be tighter.
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
su -c "/usr/lib/postgresql/12/bin/pg_ctl -D /data/database start" postgres
echo "Checking for existing DB"
if [ $(DBCheck) -eq 0 ]; then
	LOADDEFAULT="true"
	echo "Loading Default Database"
else
	LOADDEFAULT="false"
fi

echo "Running first start configuration..."

if ! [ -f /data/var-lib/gvm/private/CA/cakey.pem ]; then
	echo "Generating certs..."
    	gvm-manage-certs -a
fi

if [ $LOADDEFAULT = "true" ] && [ $NEWDB = "false" ] ; then
	echo "########################################"
	echo "Creating a base DB from /usr/lib/base-db.xz"
	echo "base data from:"
	cat /update.ts
	echo "########################################"
	# Remove the role creation as it already exists. Prevents an error in startup logs during db restoral.
	xzcat /usr/lib/base.sql.xz | grep -v "CREATE ROLE postgres" > /data/base-db.sql
	echo "CREATE TABLE IF NOT EXISTS vt_severities (id SERIAL PRIMARY KEY,vt_oid text NOT NULL,type text NOT NULL, origin text,date integer,score double precision,value text);" >> /data/dbupdate.sql
	echo "SELECT create_index ('vt_severities_by_vt_oid','vt_severities', 'vt_oid');" >> /data/dbupdate.sql
	echo "ALTER TABLE vt_severities OWNER TO gvm;" >> /data/dbupdate.sql
	touch /usr/local/var/log/db-restore.log
	chown postgres /data/base-db.sql /usr/local/var/log/db-restore.log /data/dbupdate.sql
	su -c "/usr/lib/postgresql/12/bin/psql < /data/base-db.sql " postgres > /usr/local/var/log/db-restore.log
	su -c "/usr/lib/postgresql/12/bin/psql gvmd < /data/dbupdate.sql " postgres >> /usr/local/var/log/db-restore.log
	rm /data/base-db.sql
	cd /data 
	echo "Unpacking base feeds data from /usr/lib/var-lib.tar.xz"
	tar xf /usr/lib/var-lib.tar.xz 
fi

# If NEWDB is true, then we need to create an empty database. 
if [ $NEWDB = "true" ]; then
	if [ $(DBCheck) -eq 1 ]; then
		echo " It looks like there is already a gvmd database."
		echo " Failing out to prevent overwriting the existing DB"
		exit 
	fi
        echo "Creating Greenbone Vulnerability Manager database"
        su -c "createuser -DRS gvm" postgres
        su -c "createdb -O gvm gvmd" postgres
        su -c "psql --dbname=gvmd --command='create role dba with superuser noinherit;'" postgres
        su -c "psql --dbname=gvmd --command='grant dba to gvm;'" postgres
        su -c "psql --dbname=gvmd --command='create extension \"uuid-ossp\";'" postgres
        su -c "psql --dbname=gvmd --command='create extension \"pgcrypto\";'" postgres
        chown postgres:postgres -R /data/database
        su -c "/usr/lib/postgresql/12/bin/pg_ctl -D /data/database restart" postgres
        if [ ! /data/var-lib/gvm/CA/servercert.pem ]; then
                echo "Generating certs..."
        gvm-manage-certs -a
        fi
	cd /data
        echo "Unpacking base feeds data from /usr/lib/var-lib.tar.xz"
        tar xf /usr/lib/var-lib.tar.xz
        touch /data/setup
fi
# if RESTORE is true, hopefully the user has mounted thier database in the right place.
if [ $RESTORE = "true" ] ; then
        echo "########################################"
        echo "Restoring  from /usr/lib/db-backup.sql"
        echo "########################################"
	if ! [ -f /usr/lib/db-backup.sql ]; then
		echo "You have set the RESTORE env varible to true, but there is no db to restore from."
		echo "Make sure you include \" -v <path to your backup.sql>:/usr/lib/db-backup.sql\""
		echo "on the command line to start the container."
		exit 
	fi
	touch /usr/local/var/log/restore.log
        chown postgres /usr/lib/db-backup.sql
	echo "DROP DATABASE IF EXISTS gvmd" > /tmp/dropdb.sql 
	su -c "/usr/lib/postgresql/12/bin/psql < /tmp/dropdb.sql" postgres &> /usr/local/var/log/restore.log
        su -c "/usr/lib/postgresql/12/bin/psql < /usr/lib/db-backup.sql " postgres &>> /usr/local/var/log/restore.log
	su -c "/usr/lib/postgresql/12/bin/pg_ctl -D /data/database stop" postgres
	echo " Your database backup from /usr/lib/db-backup.sql has been restored." 
	echo " You should NOT keep the container running with the RESTORE env var set"
	echo " as a restart of the container will overwrite the database again." 
	exit
fi


if [ ! -d /usr/local/var/lib/gvm/data-objects/gvmd/21.04/report_formats ]; then
	echo "Creating dir structure for feed sync"
	for dir in configs port_lists report_formats; do 
		su -c "mkdir -p /usr/local/var/lib/gvm/data-objects/gvmd/21.04/${dir}" gvm
	done
fi


# Before we migrate the DB and start gvmd, this is a good place to stop for a debug
if [ "$DEBUG" == "true" ]; then
	echo "Sleeping here for 1d to debug"
	sleep 1d
fi


# Before migration, make sure the 21.04 tables are availabe incase this is an upgrade from 20.08
echo "CREATE TABLE IF NOT EXISTS vt_severities (id SERIAL PRIMARY KEY,vt_oid text NOT NULL,type text NOT NULL, origin text,date integer,score double precision,value text);" >> /data/dbupdate.sql
echo "SELECT create_index ('vt_severities_by_vt_oid','vt_severities', 'vt_oid');" >> /data/dbupdate.sql
echo "ALTER TABLE vt_severities OWNER TO gvm;" >> /data/dbupdate.sql
touch /usr/local/var/log/db-restore.log
chown postgres /usr/local/var/log/db-restore.log /data/dbupdate.sql
su -c "/usr/lib/postgresql/12/bin/psql gvmd < /data/dbupdate.sql " postgres >> /usr/local/var/log/db-restore.log

# And it should be empty. (Thanks felimwhiteley )
if [ -f /usr/local/var/run/feed-update.lock ]; then
        # If NVT updater crashes it does not clear this up without intervention
        echo "Removing feed-update.lock"
	rm /usr/local/var/run/feed-update.lock
fi

# Migrate the DB to current gvmd version
echo "Migrating the database to the latest version if needed."
su -c "gvmd --migrate" gvm

if [ $SKIPSYNC == "false" ]; then
   echo "Updating NVTs and other data"
   echo "This could take a while if you are not using persistent storage for your NVTs"
   echo " or this is the first time pulling to your persistent storage."
   echo " the time will be mostly dependent on your available bandwidth."
   echo " We sleep for 5 seconds between sync command to make sure everything closes"
   echo " and it doesnt' look like we are connecting more than once."
   
   # This will make the feed syncs a little quieter
   if [ $QUIET == "TRUE" ] || [ $QUIET == "true" ]; then
	   QUIET="true"
	   echo " Fine, ... we'll be quiet, but we warn you if there are errors"
	   echo " syncing the feeds, you'll miss them."
   else
	   QUIET="false"
   fi
   
   if [ $QUIET == "true" ]; then 
	   echo " Pulling NVTs from greenbone" 
	   su -c "/usr/local/bin/greenbone-nvt-sync" gvm 2&> /dev/null
	   sleep 2
	   echo " Pulling scapdata from greenbone"
	   su -c "/usr/local/sbin/greenbone-feed-sync --type SCAP" gvm 2&> /dev/null
	   sleep 2
	   echo " Pulling cert-data from greenbone"
	   su -c "/usr/local/sbin/greenbone-feed-sync --type CERT" gvm 2&> /dev/null
	   sleep 2
	   echo " Pulling latest GVMD Data from greenbone" 
	   su -c "/usr/local/sbin/greenbone-feed-sync --type GVMD_DATA " gvm 2&> /dev/null
   
   else
	   echo " Pulling NVTs from greenbone" 
	   su -c "/usr/local/bin/greenbone-nvt-sync" gvm
	   sleep 2
	   echo " Pulling scapdata from greenbone"
	   su -c "/usr/local/sbin/greenbone-feed-sync --type SCAP" gvm
	   sleep 2
	   echo " Pulling cert-data from greenbone"
	   su -c "/usr/local/sbin/greenbone-feed-sync --type CERT" gvm
	   sleep 2
	   echo " Pulling latest GVMD Data from Greenbone" 
	   su -c "/usr/local/sbin/greenbone-feed-sync --type GVMD_DATA " gvm
   
   fi

fi

echo "Starting Greenbone Vulnerability Manager..."
su -c "gvmd  -a 0.0.0.0 -p 9390 --listen-group=gvm  --osp-vt-update=/var/run/ospd/ospd.sock --max-email-attachment-size=64000000 --max-email-include-size=64000000 --max-email-message-size=64000000" gvm


until su -c "gvmd --get-users" gvm; do
	echo "Waiting for gvmd"
	sleep 1
done

echo "Time to fixup the gvm accounts."

if [ "$USERNAME" == "admin" ] && [ "$PASSWORD" != "admin" ] ; then
	# Change the admin password
	echo "Setting admin password"
	su -c "gvmd --user=\"$USERNAME\" --new-password='$PASSWORD' " gvm  
elif [ "$USERNAME" != "admin" ] ; then 
	# create user and set password
	echo "Creating new user $USERNAME with supplied password."
	echo "If no password supplied on startup, then the default password is admin" 
	echo " ...... Don't do that ..... "
	echo "Creating Greenbone Vulnerability Manager admin user as $USERNAME"
	su -c "gvmd --role=\"Super Admin\" --create-user=\"$USERNAME\" --password=\"$PASSWORD\"" gvm
	echo "admin user created"
	ADMINUUID=$(su -c "gvmd --get-users --verbose | awk /$USERNAME/'{print \$2}' " gvm)
	echo "admin user UUID is $ADMINUUID"
	echo "Granting admin access to defaults"
	su -c "gvmd --modify-setting 78eceaec-3385-11ea-b237-28d24461215b --value $ADMINUUID" gvm
	# Now ... we need to remove the "admin" account ...
	su -c "gvmd --delete-user=admin" gvm 
elif [ $NEWDB = "true" ]; then
	echo "Creating Greenbone Vulnerability Manager admin user $USERNAME"
	su -c "gvmd --role=\"Super Admin\" --create-user=\"$USERNAME\" --password=\"$PASSWORD\"" gvm
	echo "admin user created"
	ADMINUUID=$(su -c "gvmd --get-users --verbose | awk '{print \$2}' " gvm)
	echo "admin user UUID is $ADMINUUID"
	echo "Granting admin access to defaults"
	su -c "gvmd --modify-setting 78eceaec-3385-11ea-b237-28d24461215b --value $ADMINUUID" gvm
fi

echo "reset "
set -Eeuo pipefail
touch /setup



if [ -f /var/run/ospd.pid ]; then
  rm /var/run/ospd.pid
fi


echo "Starting Postfix for report delivery by email"
# Configure postfix
sed -i "s/^relayhost.*$/relayhost = ${RELAYHOST}:${SMTPPORT}/" /etc/postfix/main.cf
# Start the postfix  bits
#/usr/lib/postfix/sbin/master -w
service postfix start


echo "Starting Open Scanner Protocol daemon for OpenVAS..."
ospd-openvas --log-file /usr/local/var/log/gvm/ospd-openvas.log \
             --unix-socket /var/run/ospd/ospd.sock --log-level INFO --socket-mode 777


# wait for ospd to start by looking for the socket creation.
while  [ ! -S /var/run/ospd/ospd.sock ]; do
	sleep 1
done

# We run ospd-openvas in the container as root. This way we don't need sudo.
# But if we leave the socket owned by root, gvmd can not communicate with it.
chgrp gvm /var/run/ospd/ospd.sock

echo "Starting Greenbone Security Assistant..."
#su -c "gsad --verbose --http-only --no-redirect --port=9392" gvm
if [ $HTTPS == "true" ]; then
	su -c "gsad --mlisten 127.0.0.1 -m 9390 --verbose --timeout=$GSATIMEOUT \
		    --gnutls-priorities=SECURE128:+SECURE192:-VERS-TLS-ALL:+VERS-TLS1.2 \
		    --no-redirect \
		    --port=9392" gvm
else
	su -c "gsad --mlisten 127.0.0.1 -m 9390 --verbose --timeout=$GSATIMEOUT --http-only --no-redirect --port=9392" gvm
fi
GVMVER=$(su -c "gvmd --version" gvm ) 
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "+ Your GVM/openvas/postgresql container is now ready to use! +"
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo ""
echo "gvmd --version"
echo "$GVMVER"
echo ""
echo "Image DB date:"
cat /update.ts
echo "Versions:"
cat /gvm-versions
echo "++++++++++++++++"
echo "+ Tailing logs +"
echo "++++++++++++++++"
tail -F /usr/local/var/log/gvm/* &
# This is part of making sure we shutdown postgres properly on container shutdown.
wait $!
