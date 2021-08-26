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
GMP=${GMP:-9390}
GSATIMEOUT=${GSATIMEOUT:-15}


if [ $GMP != "false" ]; then
        GMP="-a 0.0.0.0  -p $GMP"
fi

if [ ! -d "/run/redis" ]; then
	mkdir /run/redis
fi
if  [ -S /run/redis/redis.sock ]; then
        rm /run/redis/redis.sock
fi

function DBCheck {
	echo "Checking for existing DB"
        su -c " psql -lqt " postgres 
        DB=$(su -c " psql -lqt" postgres | awk /gvmd/'{print $1}')
        if [ "$DB" = "gvmd" ]; then
                echo "There seems to be an existing gvmd database. "
                echo "Failing out to prevent database deletion."
		echo "DB is $DB"
                exit
        fi
}

# Does redis need to be bound to 0.0.0.0 or will it work with just local host?
redis-server --unixsocket /run/redis/redis.sock --unixsocketperm 700 \
             --timeout 0 --databases $REDISDBS --maxclients 4096 --daemonize yes \
             --port 6379 --bind 0.0.0.0 --loglevel warning --logfile /usr/local/var/log/gvm/redis-server.log

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
su -c "/usr/lib/postgresql/12/bin/pg_ctl -D /data/database start" postgres

echo "Running first start configuration..."
if !  grep -qs gvm /etc/passwd ; then 
	echo "Adding gvm user"
	useradd --home-dir /usr/local/share/gvm gvm
fi
chown gvm:gvm -R /usr/local/share/gvm /data/var-log
#  Need these for the sockets This might neeed to be somewhere else
if [ ! -d /run/gvm ]; then
	mkdir -p /run/gvm
	mkdir -p /run/ospd
	chmod 770 /run/gvm /run/ospd
	chgrp gvm /run/gvm /run/ospd

fi


if [ ! -d /usr/local/var/lib/gvm/cert-data ]; then 
	mkdir -p /usr/local/var/lib/gvm/cert-data; 
fi

if  grep -qs -- "-ltvrP" /usr/local/bin/greenbone-nvt-sync ; then 
	echo "Fixing feed rsync options"
	sed -i -e "s/-ltvrP/-ltrP/g" /usr/local/bin/greenbone-nvt-sync 
	sed -i -e "s/-ltvrP/-ltrP/g" /usr/local/sbin/greenbone-feed-sync 
	#sed -i -e "s/-ltvrP/\$RSYNC_OPTIONS/g" /usr/local/bin/greenbone-nvt-sync 
	#sed -i -e "s/-ltvrP/\$RSYNC_OPTIONS/g" /usr/local/sbin/greenbone-feed-sync 
fi


if ! [ -f /data/var-lib/gvm/private/CA/cakey.pem ]; then
	echo "Generating certs..."
    	gvm-manage-certs -a
fi

if [ $LOADDEFAULT = "true" ] && [ $NEWDB = "false" ] ; then
	DBCheck
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
	DBCheck
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

# Always make sure these are right.

chown gvm:gvm -R /data/var-lib /usr/local/var 
chmod 770 -R /data/var-lib/gvm

if [ ! -d /usr/local/var/lib/gvm/data-objects/gvmd/20.08/report_formats ]; then
	echo "Creating dir structure for feed sync"
	for dir in configs port_lists report_formats; do 
		su -c "mkdir -p /usr/local/var/lib/gvm/data-objects/gvmd/20.08/${dir}" gvm
	done
fi

mkdir -p /usr/local/var/lib/openvas/plugins
chown -R gvm:gvm /usr/local/var/lib/openvas 

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

# Migrate the DB to current gvmd version
echo "Migrating the database to the latest version if needed."
su -c "gvmd --migrate" gvm

# Fix perms on var/run for the sync to function
if [ ! -d /usr/local/var/run ]; then
	mkdir -p /usr/local/var/run
fi
chmod 777 /usr/local/var/run/
# And it should be empty. (Thanks felimwhiteley )
if [ -f /usr/local/var/run/feed-update.lock ]; then
        # If NVT updater crashes it does not clear this up without intervention
        echo "Removing feed-update.lock"
	rm /usr/local/var/run/feed-update.lock
fi
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
	   su -c "/usr/local/sbin/greenbone-scapdata-sync" gvm 2&> /dev/null
	   sleep 2
	   echo " Pulling cert-data from greenbone"
	   su -c "/usr/local/sbin/greenbone-certdata-sync" gvm 2&> /dev/null
	   sleep 2
	   echo " Pulling latest GVMD Data from greenbone" 
	   su -c "/usr/local/sbin/greenbone-feed-sync --type GVMD_DATA " gvm 2&> /dev/null
   
   else
	   echo " Pulling NVTs from greenbone" 
	   su -c "/usr/local/bin/greenbone-nvt-sync" gvm
	   sleep 2
	   echo " Pulling scapdata from greenbone"
	   su -c "/usr/local/sbin/greenbone-scapdata-sync" gvm
	   sleep 2
	   echo " Pulling cert-data from greenbone"
	   su -c "/usr/local/sbin/greenbone-certdata-sync" gvm
	   sleep 2
	   echo " Pulling latest GVMD Data from Greenbone" 
	   su -c "/usr/local/sbin/greenbone-feed-sync --type GVMD_DATA " gvm
   
   fi

fi

echo "Starting Greenbone Vulnerability Manager..."
su -c "gvmd  $GMP --listen-group=gvm  --osp-vt-update=/var/run/ospd/ospd.sock --max-email-attachment-size=64000000 --max-email-include-size=64000000 --max-email-message-size=64000000" gvm


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

# because ....
chown -R gvm:gvm /data/var-lib 


if [ -f /var/run/ospd.pid ]; then
  rm /var/run/ospd.pid
fi


echo "Starting Postfix for report delivery by email"
# Configure postfix
sed -i "s/^relayhost.*$/relayhost = ${RELAYHOST}:${SMTPPORT}/" /etc/postfix/main.cf
# Start the postfix  bits
#/usr/lib/postfix/sbin/master -w
service postfix start

if [ -S /tmp/ospd.sock ]; then
  rm /tmp/ospd.sock
fi
echo "Starting Open Scanner Protocol daemon for OpenVAS..."
ospd-openvas --log-file /usr/local/var/log/gvm/ospd-openvas.log \
             --unix-socket /var/run/ospd/ospd.sock --log-level INFO --socket-mode 777


# wait for ospd to start by looking for the socket creation.
while  [ ! -S /var/run/ospd/ospd.sock ]; do
	sleep 1
done

chgrp gvm /var/run/ospd/ospd.sock

echo "Starting Greenbone Security Assistant..."
#su -c "gsad --verbose --http-only --no-redirect --port=9392" gvm
if [ $HTTPS == "true" ]; then
	su -c "gsad --mlisten 127.0.0.1 -m 9390 --verbose --timeout=$GSATIMEOUT \
	            --gnutls-priorities=SECURE128:+SECURE192:-VERS-TLS-ALL:+VERS-TLS1.2 \
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
echo "++++++++++++++++"
echo "+ Tailing logs +"
echo "++++++++++++++++"
tail -F /usr/local/var/log/gvm/* &
# This is part of making sure we shutdown postgres properly on container shtudown.
wait $!
