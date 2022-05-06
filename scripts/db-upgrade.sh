#!/bin/bash
# Called when postgresql fails to start ... 

# Basic steps:
# install previous version of postgresql
# setup additional directory for upgrade
# init new DB in new dir
# Backup existing DB
# Upgrade DB
# Delete old DB
# mv new/upgraded DB to /data/database
# Hope for the best ...
echo "Looking for indication of database mismatch."
STATUS=$(tail -25 /var/log/postgresql/postgresql-gvmd.log | awk /DETAIL:.*Server.is.version/'{ print $(NF - 4) $NF}')
if [ -z $STATUS ]; then
	echo "There does not appear to be a difference in databases versions.... $STATUS"
	echo "exiting now"
	exit
else
	echo "Looks like we need to upgrade the DB $STATUS"
fi

OLD=$(echo $STATUS | sed -e "s/,/ /;s/\./ /" | awk '{print $1}')
NEW=$(echo $STATUS | sed -e "s/,/ /;s/\./ /" | awk '{print $2}')

echo "Installing postgresql-$OLD"
apt update
apt install postgresql-$OLD -y
echo "Creating temp directory for upgrade...."
mkdir /data/db-upgrade
chown postgres /data/db-upgrade
echo "Initializing new DB for upgrade... "
su -c  "/usr/lib/postgresql/$NEW/bin/initdb -D /data/db-upgrade" postgres
echo "Upgrading the DB ..... "
echo "Cross your fingers ......."

#Setup environment

export PGDATAOLD=/data/database
export PGDATANEW=/data/db-upgrade
export PGBINOLD=/usr/lib/postgresql/$OLD/bin
export PGBINNEW=/usr/lib/postgresql/$NEW/bin
# Pray and hope for the best
cd /data/db-upgrade
su -c  "/usr/lib/postgresql/$NEW/bin/pg_upgrade " postgres
if [ $? -eq 0 ]; then
	echo "Looks like a success!!"
	exit $?
else
	echo " Uh Oh! $?"
	exit $?
fi
