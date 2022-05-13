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

# First, let's make sure we have some logs to go on. 
su -c "/usr/lib/postgresql/13/bin/postgres -D /data/database >> /var/log/postgresql/postgresql-gvmd.log 2>&1 &" postgres
# wait for it to fail.
sleep 5
echo " Log status ...."
ls -l /var/log/postgresql
tail -50 /var/log/postgresql/postgresql-gvmd.log 
echo " Log status done. " 
echo "Looking for indication of database mismatch."
STATUS=$(tail -25 /var/log/postgresql/postgresql-gvmd.log | awk /initialized.by.PostgreSQL.version/'{ print $14 $22}')
if [ -z $STATUS ]; then
	echo "There does not appear to be a difference in databases versions.... $STATUS"
	echo "exiting now"
	exit
else
	echo "Looks like we need to upgrade the DB $STATUS"
fi

OLD=$(echo $STATUS | sed -e "s/,/ /;s/\./ /" | awk '{print $1}')
NEW=$(echo $STATUS | sed -e "s/,/ /;s/\..*/ /" | awk '{print $2}')

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
	echo "mv $PGDATAOLD to $PGDATAOLD.$OLD"
	mv $PGDATAOLD $PGDATAOLD.$OLD
	echo "mv $PGDATANEW to $PGDATAOLD"
	mv $PGDATANEW $PGDATAOLD
	
	echo " Upgrade complete !"
	echo " Returning to startup"
	exit 0
else
	echo " Uh Oh! $?"
	exit $?
fi

