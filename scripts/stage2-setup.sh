#!/bin/bash 
# This will setup all the links and directories required by the image. 
mkdir -p /run/gvm
mkdir -p /run/ospd
mkdir -p /run/redis
mkdir -p /etc/openvas
mkdir -p /usr/local/var
# These need a check for creation on a new volume in start.sh
mkdir -p /data/database
mkdir -p /data/var-lib/gvm
mkdir -p /data/var-lib/openvas
mkdir -p /data/var-log/gvm
mkdir -p /data/local-share/gvm
mkdir -p /data/var-lib/gvm/cert-data
mkdir -p /data/var-lib/gvm/scap-data
mkdir -p /data/var-lib/gvm/data-objects
mkdir -p /data/var-lib/gvm/private/CA/
mkdir -p /data/var-lib/openvas/plugins

# Link the database to the /data folder where the volume should be mounted
mv /var/lib/postgresql/12/main/* /data/database/ 
rm -rf /var/lib/postgresql/12/main
ln -s /data/database /var/lib/postgresql/12/main

# Fix up var/lib 
cp -rf /usr/local/var/lib/* /data/var-lib/
cp -rf /var/lib/* /data/var-lib/
rm -rf /usr/local/var/lib
rm -rf /var/lib 
ln -s /data/var-lib /var/lib
ln -s /data/var-lib /usr/local/var/lib

# Fix up var/log
cp -rf /usr/local/var/log/* /data/var-log/
rm -rf /usr/local/var/log
ln -s /data/var-log /usr/local/var/log 
cp -rf /var/log/* /data/var-log/
rm -rf /var/log 
ln -s /data/var-log /var/log

# Fix up local/share
cp -rpf /usr/local/share/* /data/local-share
rm -rf /usr/local/share
ln -s /data/local-share /usr/local/share

# Fix up run
rm -rf /usr/local/var/run
ln -s /run  /usr/local/var/run

# Create gvm user
useradd --home-dir /usr/local/share/gvm gvm

# Fix ownership and permissions
chown -R postgres:postgres /data/database
chmod 750 /data/database
chown -R gvm:gvm /data/var-lib/gvm
chown -R gvm:gvm /data/var-log/gvm
chown gvm:gvm /run/gvm /run/ospd
chmod 770 /run/gvm /run/ospd
chown -R gvm:gvm  /data/var-lib/openvas/plugins
chown -R gvm:gvm /data/local-share/gvm
chmod 777 /run
