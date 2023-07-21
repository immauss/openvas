#!/usr/bin/env bash
set -Eeuo pipefail
sleep 2
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
REPORT_LINES=${REPORT_LINES:-1000}

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
    	su -c "gvm-manage-certs -a" gvm 
fi
# At this point, we have a few possible scenarios:
# 1. New build that needs a default DB loaded from the image.
# 2. Slim image with no data and empty DB created via postgresql.sh startup. 
# 3. existing Database ready to be used. 
# 4. Old databse that needs to be upgraded from pg12
# 5. Old databse that needs gvmd --migrate but is already on pg13
# LOADDEFAULT is set in /run/loaddefault via postgresql.sh 
# SHIT... that's a mess. 



LOADDEFAULT=$(cat /run/loaddefault)
echo "LOADDEFAULT is $LOADDEFAULT" 
if [ $LOADDEFAULT = "true" ] ; then
	DBCheck
	echo "########################################"
	echo "Creating a base DB from /usr/lib/base-db.xz"
	echo "########################################"
	# Remove the role creation as it already exists. Prevents an error in startup logs during db restoral.
	xzcat /usr/lib/base.sql.xz | grep -v "CREATE ROLE postgres" > /data/base-db.sql
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
	if [ -f /data/var-lib/update.ts ]; then
		echo "Initial Image DB creation date:"
		cat /data/var-lib/update.ts
	fi
fi


if [ ! -d /usr/local/var/lib/gvm/data-objects/gvmd/21.04/report_formats ]; then
	echo "Creating dir structure for feed sync"
	for dir in configs port_lists report_formats; do 
		su -c "mkdir -p /usr/local/var/lib/gvm/data-objects/gvmd/21.04/${dir}" gvm
	done
fi

# IF the GVMd database version is less than 250, then we must be on version 21.4. 
# So we need to grok the database or the migration will fail. . . . 
# Also need to extract feeds so notus has it's bits.
DB=$(su -c "psql -tq --username=postgres --dbname=gvmd --command=\"select value from meta where name like 'database_version';\"" postgres)
echo "Current GVMd database version is $DB"

if [ $DB -lt 250 ]; then
	echo "Extract feeds for 22.4"
		cd /data
		echo "Unpacking base feeds data from /usr/lib/var-lib.tar.xz"
		tar xf /usr/lib/var-lib.tar.xz
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
su -c "gvmd  $GMP --listen-group=gvm  --osp-vt-update=/var/run/ospd/ospd-openvas.sock --max-email-attachment-size=64000000 --max-email-include-size=64000000 --max-email-message-size=64000000" gvm


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
# Set number of lines in reports
echo "Setting Report Lines to $REPORT_LINES"
su -c "gvmd --modify-setting 76374a7a-0569-11e6-b6da-28d24461215b --value=$REPORT_LINES" gvm

echo "Starting Postfix for report delivery by email"
# Configure postfix
sed -i "s/^relayhost.*$/relayhost = ${RELAYHOST}:${SMTPPORT}/" /etc/postfix/main.cf
# Start the postfix  bits
#/usr/lib/postfix/sbin/master -w
service postfix start
tail -f /usr/local/var/log/gvm/gvmd.log &
#WTF ???? Why did I do this?
pkill gvmd
su -c "exec gvmd -f $GMP --listen-group=gvm  --osp-vt-update=/var/run/ospd/ospd-openvas.sock --max-email-attachment-size=64000000 --max-email-include-size=64000000 --max-email-message-size=64000000" gvm
 


