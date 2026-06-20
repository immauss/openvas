#!/usr/bin/env bash
MODE="$1"
#Define  proper shutdown 
cleanup() {
	echo "Container stopped, performing shutdown"
	echo "#################################"
	echo "Dumping all logs"
	echo "#################################"
	rm -f /running
    tail /var/log/gvm/*
	echo "Log dump complete"
	echo "killing gvmd"
	pkill gvmd
	sleep 1
	echo "Stopping postgresql"
    su -c "/usr/lib/postgresql/${PGVER}/bin/pg_ctl -D /data/database stop" postgres
	
}

#Trap SIGTERM
if [ -z $1 ] || [ "$1" != "refresh" ]; then
	echo "Starting trap for clean db exit."
	trap 'cleanup' EXIT
fi

set -Eeuo pipefail
PGVER=${PGVER:-15}
USERNAME=${USERNAME:-admin}
PASSWORD=${PASSWORD:-admin}
RELAYHOST=${RELAYHOST:-172.17.0.1}
SMTPPORT=${SMTPPORT:-25}
REDISDBS=${REDISDBS:-512}
QUIET=${QUIET:-false}
# use this to rebuild the DB from scratch instead of using the one in the image.
CREATE_EMPTY_DATABASE=${NEWDB:-false}
SKIPSYNC=${SKIPSYNC:-false}
RESTORE=${RESTORE:-false}
DEBUG=${DEBUG:-false}
HTTPS=${HTTPS:-false}
#GMP=${GMP:-9390}
GSATIMEOUT=${GSATIMEOUT:-15}
GVMD_ARGS=${GVMD_ARGS:-blank}
GSAD_ARGS=${GSAD_ARGS:-blank}
REPORT_LINES=${REPORT_LINES:-1000}
SKIPGSAD=${SKIPGSAD:-false}
if [ $GVMD_ARGS == "blank" ]; then
	GVMD_ARGS='--'
fi
if [ "$DEBUG" == "true" ]; then
	for var in USERNAME PASSWORD RELAYHOST SMTPPORT REDISDBS QUIET CREATE_EMPTY_DATABASE SKIPSYNC RESTORE DEBUG HTTPS GSATIMEOUT SKIPGSAD; do 
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

# Make sure the gvmd.pid is not there to ensure healthcheck doesn't start early. 
rm -f /run/gvmd/gvmd.pid
rm -f /running

# Fire up redis
redis-server --unixsocket /run/redis/redis.sock --unixsocketperm 777 \
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
	chown postgres:postgres -R /data/database
fi
PGFAIL=0
PGUPFAIL=0
INITFAIL=0
echo "Starting PostgreSQL..."
# if ! [ -d /data/database/base ]; then
# 	ls -l /data/database
# 	echo "Looks like there is no initial DB"
# 	echo "Initializing /data/database for postgresql use."
# 	su -c "/usr/lib/postgresql/${PGVER}/bin/initdb -D /data/database" postgres || INITFAIL=$?
# 	if [ $INITFAIL -ne 0 ]; then
# 		echo "Looks like databse init failed. \"$INITFAIL\" Bailing out."
# 		exit
# 	fi
# fi
su -c "/usr/lib/postgresql/${PGVER}/bin/pg_ctl -D /data/database start" postgres || PGFAIL=$?
echo "pg exit with $PGFAIL ." 
if [ $PGFAIL -ne 0 ]; then
	echo "It looks like postgres failed to start. ( Exit code: \"$?\" "
	echo "Assuming this is due to different database version and starting upgrade."
	#/scripts/db-upgrade.sh || PGUPFAIL=$?
	/scripts/pg13-2-15.sh || PGUPFAIL=$?
	if [ $PGUPFAIL -ne 0 ]; then
		echo "Looks like this is either not an upgrade problem, or the upgrade failed."
		exit
	else
		echo " DB Upgrade was a success. Starting postgresql $PGVER"
		su -c "/usr/lib/postgresql/${PGVER}/bin/pg_ctl -D /data/database start" postgres
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
    	su -c "/usr/local/bin/gvm-manage-certs -afv" gvm 
fi
# if there is no existing DB, and there is no base db archive, then we need to create a new DB.
if [ $(DBCheck) -eq 0 ] && ! [ -f /usr/lib/gvmd.sql.xz ]; then
		echo "Looks like we need to create an empty databse."
		CREATE_EMPTY_DATABASE="true"
		# Set SKIPSYNC to false so we pull new feeds
		SKIPSYNC="false"
		# Set LOADDEFAULT to false because we don't have the DB.
		LOADDEFAULT="false"
fi
echo -e "CREATE_EMPTY_DATABASE=$CREATE_EMPTY_DATABASE\nLOADDEFAULT=$LOADDEFAULT"

# Here we load the DB from the image, but only if there is a DB file on the image.
if [ $LOADDEFAULT = "true" ] && [ $CREATE_EMPTY_DATABASE = "false" ] ; then
	echo "########################################"
	echo "Creating a base DB from /usr/lib/base-db.xz"
	echo "########################################"
	# Remove the role creation as it already exists. Prevents an error in startup logs during db restoral.
	#xzcat /usr/lib/base.sql.xz | grep -v "CREATE ROLE postgres" > /data/base-db.sql
	xzcat /usr/lib/globals.sql.xz  | grep -v "CREATE ROLE postgres" > /data/globals.sql
	xzcat /usr/lib/gvmd.sql.xz  > /data/gvmd.sql
	# the dump is putting this command in the backup even though the value is null. 
	# this causes errors on start up as with the value as a null, it looks like a syntax error.
	# removing it here, but only if it exists as a null. If in the future, this is not null, it should remain.
	if grep -qs "^CREATE AGGREGATE public\.group_concat()" /data/base-db.sql; then
		sed -i '/CREATE AGGREGATE public\.group_concat()/,+4d' /data/base-db.sql
		sed -i '/^ALTER AGGREGATE public\.group_concat()/d' /data/base-db.sql
	fi
	touch /usr/local/var/log/db-restore.log

	echo "Restoring Globals."
	su -c "/usr/lib/postgresql/${PGVER}/bin/psql  < /data/globals.sql " postgres > /usr/local/var/log/db-restore.log
	echo "Creating gvmd Database."
	su -c "createdb -O gvm gvmd" postgres
	echo "Restoring gvmd database."
	su -c "/usr/lib/postgresql/${PGVER}/bin/pg_restore  -d gvmd -j 4 /data/gvmd.sql" postgres  > /usr/local/var/log/db-restore.log
	rm /data/gvmd.sql
	cd /data 
	echo "Unpacking base feeds data from /usr/lib/var-lib.tar.xz"
	tar xf /usr/lib/var-lib.tar.xz
	echo "Base DB and feeds collected on:"
	cat /data/var-lib/update.ts
	# Store the date of the Feeds archive for later start ups. 
	stat -c %Y  /data/var-lib/update.ts  > /data/var-lib/FeedDate 
fi

# If CREATE_EMPTY_DATABASE is true, then we need to create an empty database. 
if [ $CREATE_EMPTY_DATABASE = "true" ]; then
	if [ $(DBCheck) -eq 1 ]; then
		echo " It looks like there is already a gvmd database."
		echo " Failing out to prevent overwriting the existing DB"
		exit 1
	fi
	echo "Creating Greenbone Vulnerability Manager database"
	su -c "createuser -DRS gvm" postgres
	su -c "createdb -O gvm gvmd" postgres
	su -c "psql --dbname=gvmd --command='create role dba with superuser noinherit;'" postgres
	su -c "psql --dbname=gvmd --command='grant dba to gvm;'" postgres
	su -c "psql --dbname=gvmd --command='create extension \"uuid-ossp\";'" postgres
	su -c "psql --dbname=gvmd --command='create extension \"pgcrypto\";'" postgres
	chown postgres:postgres -R /data/database
	su -c "/usr/lib/postgresql/${PGVER}/bin/pg_ctl -D /data/database restart" postgres

	su -c "gvm-manage-certs -V" gvm 
	NOCERTS=$?
	while [ $NOCERTS -ne 0 ] ; do
		su -c "gvm-manage-certs -vaf " gvm
		su -c "gvm-manage-certs -V " gvm 
		NOCERTS=$?
	done
 --rebuild-gvmd-data=report_formats

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
		exit 1
	fi
	touch /usr/local/var/log/restore.log
        chown postgres /usr/lib/db-backup.sql
	echo "DROP DATABASE IF EXISTS gvmd" > /tmp/dropdb.sql 
	su -c "/usr/lib/postgresql/${PGVER}/bin/psql < /tmp/dropdb.sql" postgres &> /usr/local/var/log/restore.log
        su -c "/usr/lib/postgresql/${PGVER}/bin/psql < /usr/lib/db-backup.sql " postgres &>> /usr/local/var/log/restore.log
	echo "Rebuilding report formats"
	su -c "gvmd --rebuild-gvmd-data=report_formats" gvm
	su -c "/usr/lib/postgresql/${PGVER}/bin/pg_ctl -D /data/database stop" postgres
	echo " Your database backup from /usr/lib/db-backup.sql has been restored." 
	echo " You should NOT keep the container running with the RESTORE env var set"
	echo " as a restart of the container will overwrite the database again." 
	exit
fi


# Before we migrate the DB and start gvmd, this is a good place to stop for a debug
if [ "$DEBUG" == "true" ]; then
	echo "Sleeping here for 1d to debug"
	sleep 1d
fi
if [ "$CREATE_EMPTY_DATABASE" == "false"  ]; then
	echo "Migrate the database if needed."
	# ps auxw | grep gvmd
	# pkill -KILL gvmd || true # damn healthcheck
	su -c "gvmd --migrate" gvm 
fi


if [ $SKIPSYNC == "false" ]; then
   echo "Updating NVTs and other data"
   echo "This could take a while if you are not using persistent storage for your NVTs"
   echo " or this is the first time pulling to your persistent storage."
   echo " the time will be mostly dependent on your available bandwidth."
   # First, let's make sure we are using the most updated feeds from the image ...
   # If the timestamp is the same, or the file doesn't exist, then we start by
   # extracting the archive in the image, this will speed up the sync with GB by
   # reducing the amount needed to rsync. But only if there is an archive. (ie .. not a slim image)
	if [ -f /usr/lib/var-lib.tar.xz ]; then
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
	fi
	   
   # This will make the feed syncs a little quieter
   # We touch a file here to note that the sync was started
   # Then remove it after sync is complete.
   # This used to detect a failed sync when the container restarts
   touch /data/feed-syncing
   if [ $QUIET == "TRUE" ] || [ $QUIET == "true" ]; then
	   echo " Fine, ... we'll be quiet, but we warn you if there are errors"
	   echo " syncing the feeds, you'll miss them."
	   echo "Syncing all feeds from GB" 
	   /scripts/sync.sh --quiet 
   else
	   echo "Syncing all feeds from GB" 
	   /scripts/sync.sh
   fi
   # if the feed-sync fails, the container will exit and this will not be run.
   rm /data/feed-syncing
fi

# This works for now, but needs to move to the "confs" 
mkdir -p /etc/openvas 
cat >/etc/openvas/openvas.conf <<'EOF'
table_driven_lsc = yes
openvasd_server = http://127.0.0.1:3000
EOF

export OPENVASD_MODE="service_notus"
echo "Starting openvasd"
openvasd --mode service_notus \
	--feed-path /var/lib/openvas \
	--advisories /var/lib/notus/advisories \
	--products /var/lib/notus/products \
	--redis-url redis://127.0.0.1/ \
	--ospd-socket /var/run/ospd/ospd-openvas.sock \
	--auto_enable_dependencies true \
	--table_driven_lsc true \
	--listening 127.0.0.1:3000 &

# wait until openvasd answers HTTP
echo "Waiting for openvasd to be ready"
sleep 3
until code=$(curl -sS -o /dev/null -w "%{http_code}" http://127.0.0.1:3000/) && [ "$code" != "000" ]; do
  echo -n "."
  sleep 1
done

echo "Starting ospd-openvas"
/usr/local/bin/ospd-openvas --unix-socket /var/run/ospd/ospd-openvas.sock \
	--foreground \
	--pid-file /run/ospd/ospd-openvas.pid \
	--log-file /usr/local/var/log/gvm/ospd-openvas.log \
	--lock-file-dir /var/lib/openvas \
	--socket-mode 0o770 \
	--notus-feed-dir /var/lib/notus/advisories \
	--disable-notus-hashsum-verification true &
echo "Waiting for ospd socket"
while ! [ -S /var/run/ospd/ospd-openvas.sock ]; do
	sleep 1
done
ls -l  /var/run/ospd/ospd-openvas.sock 

# Ensure gvmd can read from the ospd socket.
chown gvm:gvm /var/run/ospd/ospd-openvas.sock
ls -l  /var/run/ospd/ospd-openvas.sock 

# Just incase the boot took too long and there are already gvmd procs running from healthcheck

# GVMSTATUS=1
# STARTCOUNT=0
# while [ $GVMSTATUS -ne 0 ] && [ $STARTCOUNT -lt 2 ]; do
# 	pkill gvmd || true
# 	sleep 1
# 	pkill gvmd || true
	echo "Starting Greenbone Vulnerability Manager..."
	su -c "gvmd --listen-group=gvm  \
				--osp-vt-update=/var/run/ospd/ospd-openvas.sock \
				--max-email-attachment-size=64000000 \
				--max-email-include-size=64000000 \
				--max-email-message-size=64000000 \
				--broker-address='' \
				--unix-socket=/run/gvmd/gvmd.sock \
				\"$GVMD_ARGS\"" gvm 
# 	GVMSTATUS="$?"
	
# 	STARTCOUNT=$(( $STARTCOUNT + 1 ))
# 	echo -e "GVMSTATUS = $GVMSTATUS\n\tSTARTCOUNT = $STARTCOUNT\n"
# done




until su -c "gvmd --get-users" gvm; do
	echo "Waiting for gvmd"
	sleep 1
done

if ! [ -L /var/run/ospd/ospd.sock ]; then
	ln -s /var/run/ospd/ospd-openvas.sock /var/run/ospd/ospd.sock 
fi

echo "Time to fixup the gvm accounts."


if [ "$USERNAME" == "admin" ] && [ "$PASSWORD" != "admin" ] ; then
	# Change the admin password
	echo "Setting admin password"
	su -c "gvmd --user=\"$USERNAME\" --new-password=\"$PASSWORD\" " gvm  
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
elif [ $CREATE_EMPTY_DATABASE = "true" ]; then
	echo "Creating Greenbone Vulnerability Manager admin user $USERNAME"
	su -c "gvmd --role=\"Super Admin\" --create-user=\"$USERNAME\" --password=\"$PASSWORD\"" gvm
	echo "admin user created"
	ADMINUUID=$(su -c "gvmd --get-users --verbose | awk '{print \$2}' " gvm)
	echo "admin user UUID is $ADMINUUID"
	echo "Granting admin access to defaults"
	su -c "gvmd --modify-setting 78eceaec-3385-11ea-b237-28d24461215b --value $ADMINUUID" gvm
fi
# Check to see if the HealthCheck user exists. If not, create it and set a new random password.
echo "Checking for/creating healthcheck user."
touch /etc/healthcheck.pass 
chown gvm:gvm /etc/healthcheck.pass
chmod 600 /etc/healthcheck.pass
su -c "/scripts/create-hc-user.sh \"$PASSWORD\"" gvm  || true


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
# Make postfix more secureish thanks @rkoosaar
echo "disable_vrfy_command=yes
smtpd_tls_mandatory_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
smtpd_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
smtp_tls_mandatory_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
smtp_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1" >> /etc/postfix/main.cf

# Start the postfix  bits
#/usr/lib/postfix/sbin/master -w
service postfix start



# We run ospd-openvas in the container as root. This way we don't need sudo.
# But if we leave the socket owned by root, gvmd can not communicate with it.
chgrp gvm /var/run/ospd/ospd.sock

if [ $SKIPGSAD == "false" ]; then
	echo "Starting Greenbone Security Assistant..."
	#su -c "gsad --verbose --http-only --no-redirect --port=9392" gvm
	if [ $HTTPS == "true" ]; then
			# removed --mlisten 127.0.0.1 -m 9390 
			su -c "gsad --verbose --timeout=$GSATIMEOUT \
				--munix-socket=/run/gvmd/gvmd.sock \
				--gnutls-priorities=SECURE128:+SECURE192:-VERS-TLS-ALL:+VERS-TLS1.2 \
				--no-redirect \
				--port=9392 $GSAD_ARGS" gvm
	else
		su -c "gsad --verbose --timeout=$GSATIMEOUT \
		--munix-socket=/run/gvmd/gvmd.sock \
		   --http-only --no-redirect --port=9392 \
		   $GSAD_ARGS" gvm
	fi
else
	echo "Skipping GSAD start because SKIPGSAD=$SKIPGSAD"
fi
GVMVER=$(su -c "gvmd --version" gvm ) 
touch /running
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
echo "Log tail started" 
# This is part of making sure we shutdown postgres properly on container shutdown.

if [ "x$MODE" != "xrefresh" ]; then
	echo "Waiting for container to exit"
	wait $!
fi
echo "Not waiting .... "
