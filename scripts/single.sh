#!/usr/bin/env bash
set -Eeuo pipefail
#Define  proper shutdown 
cleanup() {
    echo "Container stopped, performing shutdown"
    su -c "/usr/lib/postgresql/13/bin/pg_ctl -D /data/database stop" postgres
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
GVMD_ARGS=${GVMD_ARGS:-blank}
GSAD_ARGS=${GSAD_ARGS:-blank}
REPORT_LINES=${REPORT_LINES:-1000}
if [ $GVMD_ARGS == "blank" ]; then
	GVMD_ARGS='--'
fi
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
	echo -e "host\tall\tall\t0.0.0.0/0\tmd5" >> /data/database/pg_hba.conf
	echo -e "host\tall\tall\t::0/0\tmd5" >> /data/database/pg_hba.conf
	echo -e "local\tall\tall\ttrust"  >> /data/database/pg_hba.conf
        echo "log_destination = 'stderr'" >> /data/database/postgresql.conf
        echo "logging_collector = on" >> /data/database/postgresql.conf
        echo "log_directory = '/data/var-log/postgresql/'" >> /data/database/postgresql.conf
        echo "log_filename = 'postgresql-gvmd.log'" >> /data/database/postgresql.conf
        echo "log_file_mode = 0666" >> /data/database/postgresql.conf
        echo "log_truncate_on_rotation = off" >> /data/database/postgresql.conf
        echo "log_line_prefix = '%m [%p] %q%u@%d '" >> /data/database/postgresql.conf
        echo "log_timezone = 'Etc/UTC'" >> /data/database/postgresql.conf
	chown postgres:postgres -R /data/database
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
    	su -c "gvm-manage-certs -afv" gvm 
fi
# if there is no existing DB, and there is no base db archive, then we need to create a new DB.
if [ $(DBCheck) -eq 0 ] && ! [ -f /usr/lib/base.sql.xz ]; then
		echo "Looks like we need to create an empty databse."
		NEWDB="true"
fi
echo -e "NEWDB=$NEWDB\nLOADDEFAULT=$LOADDEFAULT"

if [ $LOADDEFAULT = "true" ] && [ $NEWDB = "false" ] ; then
	echo "########################################"
	echo "Creating a base DB from /usr/lib/base-db.xz"
	echo "########################################"
	# Remove the role creation as it already exists. Prevents an error in startup logs during db restoral.
	xzcat /usr/lib/base.sql.xz | grep -v "CREATE ROLE postgres" > /data/base-db.sql
	# the dump is putting this command in the backup even though the value is null. 
	# this causes errors on start up as with the value as a null, it looks like a syntax error.
	# removing it here, but only if it exists as a null. If in the future, this is not null, it should remain.
	if grep -qs "^CREATE AGGREGATE public\.group_concat()" /data/base-db.sql; then
		sed -i '/CREATE AGGREGATE public\.group_concat()/,+4d' /data/base-db.sql
		sed -i '/^ALTER AGGREGATE public\.group_concat()/d' /data/base-db.sql
	fi
	echo "CREATE TABLE IF NOT EXISTS vt_severities (id SERIAL PRIMARY KEY,vt_oid text NOT NULL,type text NOT NULL, origin text,date integer,score double precision,value text);" >> /data/dbupdate.sql
	echo "SELECT create_index ('vt_severities_by_vt_oid','vt_severities', 'vt_oid');" >> /data/dbupdate.sql
	echo "ALTER TABLE vt_severities OWNER TO gvm;" >> /data/dbupdate.sql
	touch /usr/local/var/log/db-restore.log
	chown postgres /data/base-db.sql /usr/local/var/log/db-restore.log /data/dbupdate.sql
	su -c "/usr/lib/postgresql/13/bin/psql < /data/base-db.sql " postgres > /usr/local/var/log/db-restore.log
	su -c "/usr/lib/postgresql/13/bin/psql gvmd < /data/dbupdate.sql " postgres >> /usr/local/var/log/db-restore.log
	rm /data/base-db.sql
	cd /data 
	echo "Unpacking base feeds data from /usr/lib/var-lib.tar.xz"
	tar xf /usr/lib/var-lib.tar.xz
	echo "Base DB and feeds collected on:"
	cat /data/var-lib/update.ts
	# Store the date of the Feeds archive for later start ups. 
	stat -c %Y  /data/var-lib/update.ts  > /data/var-lib/FeedDate 
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
	su -c "/usr/lib/postgresql/13/bin/pg_ctl -D /data/database restart" postgres

	su -c "gvm-manage-certs -V" gvm 
	NOCERTS=$?
	while [ $NOCERTS -ne 0 ] ; do
		su -c "gvm-manage-certs -vaf " gvm
		su -c "gvm-manage-certs -V " gvm 
		NOCERTS=$?
	done


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
	su -c "/usr/lib/postgresql/13/bin/psql < /tmp/dropdb.sql" postgres &> /usr/local/var/log/restore.log
        su -c "/usr/lib/postgresql/13/bin/psql < /usr/lib/db-backup.sql " postgres &>> /usr/local/var/log/restore.log
	echo "Rebuilding report formats"
	su -c "gvmd --rebuild-gvmd-data=report_formats" gvm
	su -c "/usr/lib/postgresql/13/bin/pg_ctl -D /data/database stop" postgres
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

# And it should be empty. (Thanks felimwhiteley )
if [ -f /usr/local/var/run/feed-update.lock ]; then
        # If NVT updater crashes it does not clear this up without intervention
        echo "Removing feed-update.lock"
	rm /usr/local/var/run/feed-update.lock
fi


# Before we migrate the DB and start gvmd, this is a good place to stop for a debug
if [ "$DEBUG" == "true" ]; then
	echo "Sleeping here for 1d to debug"
	sleep 1d
fi

# IF the GVMd database version is less than 250, then we must be on version 21.4. 
# So we need to grok the database or the migration will fail. . . . 
if [ "$NEWDB" == "false" ]; then
	echo "Checking DB Version"
	DB=$(su -c "psql -tq --username=postgres --dbname=gvmd --command=\"select value from meta where name like 'database_version';\"" postgres)
else 
	DB=250
fi
echo "Current GVMd database version is $DB"
if [ $DB -lt 250 ]; then
	date
	echo "Groking the database so migration won't fail"
	echo "This could take a while. (10-15 minutes). "
	su -c "/usr/lib/postgresql/13/bin/psql gvmd < /scripts/21.4-to-22.4-prep.sql" postgres >> /usr/local/var/log/db-restore.log
	date
	echo "Grock complete."
	echo "Now the long part, migrating the databse."
	su -c "gvmd --migrate" gvm
	echo "Migration complete!!"
	date
else 

	# Before migration, make sure the 21.04 tables are availabe incase this is an upgrade from 20.08
	# But only if we didn't just delete most of these functions for the upgrade to 22.4
	# This whole things can probably be removed, but just incase .....
	echo "CREATE TABLE IF NOT EXISTS vt_severities (id SERIAL PRIMARY KEY,vt_oid text NOT NULL,type text NOT NULL, origin text,date integer,score double precision,value text);" >> /data/dbupdate.sql
	echo "SELECT create_index ('vt_severities_by_vt_oid','vt_severities', 'vt_oid');" >> /data/dbupdate.sql
	echo "ALTER TABLE vt_severities OWNER TO gvm;" >> /data/dbupdate.sql
	touch /usr/local/var/log/db-restore.log
	chown postgres /usr/local/var/log/db-restore.log /data/dbupdate.sql
	su -c "/usr/lib/postgresql/13/bin/psql gvmd < /data/dbupdate.sql " postgres >> /usr/local/var/log/db-restore.log
	echo "Migrate the database if needed."
	su -c "gvmd --migrate" gvm 
fi


if [ $SKIPSYNC == "false" ]; then
   echo "Updating NVTs and other data"
   echo "This could take a while if you are not using persistent storage for your NVTs"
   echo " or this is the first time pulling to your persistent storage."
   echo " the time will be mostly dependent on your available bandwidth."
   echo " We sleep for 2 seconds between sync command to make sure everything closes"
   echo " and it doesnt' look like we are connecting more than once."
   # First, let's make sure we are using the most updated feeds from the image ...
   # If the timestamp is the same, or the file doesn't exist, then we start by
   # extracting the archive in the image, this will speed up the sync with GB by
   # reducing the amount needed to rsync.
   echo "Checking age of current data feeds from Greenbone."
   ImageFeeds=$(stat -c %Y /usr/lib/var-lib.tar.xz)
   echo "ImageFeeds=$ImageFeeds"
   if [ -f /data/var-lib/FeedDate ]; then 
	   InstalledFeeds=$(cat /data/var-lib/FeedDate)
	   
   else
	   InstalledFeeds=0
   fi
   echo "InstalledFeeds=$InstalledFeeds"
   if [ $InstalledFeeds -ne $ImageFeeds ]; then
	   echo "Updating local feeds with newer image feeds."
	   cd /data
	   tar xf /usr/lib/var-lib.tar.xz
	   # Replace the FeedDate with date from the Image feeds.
	   # This prevents it from extracting the archive everytime the image restarts.
	   echo "$ImageFeeds" > /data/var-lib/FeedDate 

   fi

	   
   # This will make the feed syncs a little quieter
   if [ $QUIET == "TRUE" ] || [ $QUIET == "true" ]; then
	   QUIET="true"
	   echo " Fine, ... we'll be quiet, but we warn you if there are errors"
	   echo " syncing the feeds, you'll miss them."
   else
	   QUIET="false"
   fi
   
   if [ $QUIET == "true" ]; then 
	   echo "Syncing all feeds from GB" 
	   su -c "/usr/local/bin/greenbone-nvt-sync --type all --quiet" gvm 
   else
	   echo "Syncing all feeds from GB" 
	   su -c "/usr/local/bin/greenbone-nvt-sync --type all" gvm 
   fi
fi

echo "Starting Greenbone Vulnerability Manager..."
su -c "gvmd  -a 0.0.0.0 -p 9390 --listen-group=gvm  --osp-vt-update=/var/run/ospd/ospd-openvas.sock --max-email-attachment-size=64000000 --max-email-include-size=64000000 --max-email-message-size=64000000 \"$GVMD_ARGS\"" gvm


until su -c "gvmd --get-users" gvm; do
	echo "Waiting for gvmd"
	sleep 1
done

if ! [ -L /var/run/ospd/ospd-openvas.sock ]; then
	ln -s /var/run/ospd/ospd-openvas.sock /var/run/ospd/ospd.sock
fi

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

# Set number of lines in reports
echo " set Report Lines to $REPORT_LINES"
su -c "gvmd --modify-setting 76374a7a-0569-11e6-b6da-28d24461215b --value=$REPORT_LINES" gvm 

# If this exists ...
if [ -f /var/run/ospd.pid ]; then
  rm /var/run/ospd.pid
fi


echo "Starting Postfix for report delivery by email"
# Configure postfix
sed -i "s/^relayhost.*$/relayhost = ${RELAYHOST}:${SMTPPORT}/" /etc/postfix/main.cf
# Start the postfix  bits
#/usr/lib/postfix/sbin/master -w
service postfix start

# Start the mqtt 

chmod  777 /run/mosquitto
echo "listener 1883
allow_anonymous true" >> /etc/mosquitto.conf
/usr/sbin/mosquitto -c /etc/mosquitto/mosquitto.conf  &

echo "Starting Open Scanner Protocol daemon for OpenVAS..."
# Prep the gpg keys
export OPENVAS_GNUPG_HOME=/etc/openvas/gnupg
export GNUPGHOME=/etc/openvas-gnupg
if ! [ -f tmp/GBCommunitySigningKey.asc ]; then
	echo " Get the Greenbone public Key"
	#curl -f -L https://www.greenbone.net/GBCommunitySigningKey.asc -o /etc/GBCommunitySigningKey.asc
	#echo "8AE4BE429B60A59B311C2E739823FAA60ED1E580:6:" > /etc/ownertrust.txt
	echo "Setup environment"
	mkdir -m 0600 -p $GNUPGHOME $OPENVAS_GNUPG_HOME
	echo "Import the key "
	gpg --import /etc/GBCommunitySigningKey.asc
	gpg --import-ownertrust < /etc/ownertrust.txt
	echo "Setup key for openvas .."
	cp -r /etc/openvas-gnupg/* $OPENVAS_GNUPG_HOME/
	chown -R gvm:gvm $OPENVAS_GNUPG_HOME
fi

/usr/local/bin/ospd-openvas --unix-socket /var/run/ospd/ospd-openvas.sock \
	--pid-file /run/ospd/ospd-openvas.pid \
	--log-file /usr/local/var/log/gvm/ospd-openvas.log \
	--lock-file-dir /var/lib/openvas \
	--socket-mode 0o770 \
	--mqtt-broker-address localhost \
	--mqtt-broker-port 1883 \
	--notus-feed-dir /var/lib/notus/advisories

# wait for ospd to start by looking for the socket creation.
#while  [ ! -S /var/run/ospd/ospd-openvas.sock]; do
	#sleep 1
#done


# start notus-scanner 

/usr/local/bin/notus-scanner --products-directory /var/lib/notus/products --log-file /var/log/gvm/notus-scanner.log

# We run ospd-openvas in the container as root. This way we don't need sudo.
# But if we leave the socket owned by root, gvmd can not communicate with it.
chgrp gvm /var/run/ospd/ospd.sock
chgrp gvm /var/run/ospd/ospd-openvas.sock

echo "Starting Greenbone Security Assistant..."
#su -c "gsad --verbose --http-only --no-redirect --port=9392" gvm
if [ $HTTPS == "true" ]; then
	su -c "gsad --mlisten 127.0.0.1 -m 9390 --verbose --timeout=$GSATIMEOUT \
		    --gnutls-priorities=SECURE128:+SECURE192:-VERS-TLS-ALL:+VERS-TLS1.2 \
		    --no-redirect \
		    --port=9392 $GSAD_ARGS" gvm
else
	su -c "gsad --mlisten 127.0.0.1 -m 9390 --verbose --timeout=$GSATIMEOUT --http-only --no-redirect --port=9392 $GSAD_ARGS" gvm
fi
GVMVER=$(su -c "gvmd --version" gvm ) 
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "+ Your GVM/openvas/postgresql container is now ready to use! +"
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo ""
echo "gvmd --version"
echo "$GVMVER"
echo ""
if [ -f /data/var-lib/update.ts ]; then
	echo "Initial Image DB creation date:"
	cat /data/var-lib/update.ts
fi

echo "Versions:"
cat /gvm-versions
echo "++++++++++++++++"
echo "+ Tailing logs +"
echo "++++++++++++++++"
tail -F /usr/local/var/log/gvm/* &
# This is part of making sure we shutdown postgres properly on container shutdown.
wait $!
