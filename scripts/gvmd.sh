#!/usr/bin/env bash
set -Eeuo pipefail

USERNAME=${USERNAME:-admin}
PASSWORD=${PASSWORD:-admin}
RELAYHOST=${RELAYHOST:-172.17.0.1}
SMTPPORT=${SMTPPORT:-25}
QUIET=${QUIET:-false}
# use this to rebuild the DB from scratch instead of using the one in the image.
SKIPSYNC=${SKIPSYNC:-false}
RESTORE=${RESTORE:-false}
DEBUG=${DEBUG:-false}
HTTPS=${HTTPS:-false}
GMP=${GMP:-9390}

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
        rm -rf /usr/local/var/lib
        ln -s /data/var-lib /usr/local/var/lib
fi
if [ ! -L /usr/local/share ]; then
        echo "Fixing local/share ... "
        if [ ! -d /data/local-share ]; then mkdir /data/local-share; fi
        rm -rf /usr/local/share
        ln -s /data/local-share /usr/local/share
fi

if [ ! -L /usr/local/var/log/gvm ]; then
        echo "Fixing log directory for persistent logs .... "
        if [ ! -d /data/var-log/ ]; then mkdir /data/var-log; fi
        rm -rf /usr/local/var/log/gvm
        ln -s /data/var-log /usr/local/var/log/gvm
        chown gvm /data/var-log
fi


# Need to find a way to wait for the DB to be ready:
while [ ! -S /run/postgresql/.s.PGSQL.5432 ]; do
	echo "DB not ready yet"
	sleep 1
done

if [ $GMP != "false" ]; then
		GMP_PORT="$GMP"
        GMP="-a 0.0.0.0  -p $GMP_PORT"

fi

chown -R gvm:gvm /data/var-log

if [ ! -d /usr/local/var/lib/gvm/cert-data ]; then 
	mkdir -p /usr/local/var/lib/gvm/cert-data; 
fi


if ! [ -f /data/var-lib/gvm/private/CA/cakey.pem ]; then
	echo "Generating certs..."
    	gvm-manage-certs -a
fi
LOADDEFAULT=$(cat /run/loaddefault)
if [ $LOADDEFAULT = "true" ] ; then
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

# Always make sure these are right.
chown gvm:gvm -R /data/var-lib /usr/local/var 
chmod 770 -R /data/var-lib/gvm

if [ ! -d /usr/local/var/lib/gvm/data-objects/gvmd/21.04/report_formats ]; then
	echo "Creating dir structure for feed sync"
	for dir in configs port_lists report_formats; do 
		su -c "mkdir -p /usr/local/var/lib/gvm/data-objects/gvmd/21.04/${dir}" gvm
	done
fi

mkdir -p /usr/local/var/lib/openvas/plugins
chown -R gvm:gvm /usr/local/var/lib/openvas 



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
chgrp gvm /usr/local/var/run/
chmod 770 /usr/local/var/run
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
echo "gvmd  $GMP --listen-group=gvm  --osp-vt-update=/var/run/ospd/ospd.sock --max-email-attachment-size=64000000 --max-email-include-size=64000000 --max-email-message-size=64000000" 
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
fi


touch /setup

echo "Starting Postfix for report delivery by email"
# Configure postfix
sed -i "s/^relayhost.*$/relayhost = ${RELAYHOST}:${SMTPPORT}/" /etc/postfix/main.cf
# Start the postfix  bits
#/usr/lib/postfix/sbin/master -w
service postfix start
tail -f /usr/local/var/log/gvm/gvmd.log &
pkill gvmd
su -c "exec gvmd -f $GMP --listen-group=gvm  --osp-vt-update=/var/run/ospd/ospd.sock --max-email-attachment-size=64000000 --max-email-include-size=64000000 --max-email-message-size=64000000" gvm
 


