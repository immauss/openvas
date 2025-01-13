#!/bin/bash 
# This will setup all the links and directories required by the image. 
echo "Creating needed Directories"
mkdir -p /run/gvm
mkdir -p /run/ospd
mkdir -p /run/gvmd
mkdir -p /run/redis
mkdir -p /run/gsad
mkdir -p /run/mosquitto
mkdir -p /run/notus-scanner
mkdir -p /etc/openvas
mkdir -p /usr/local/var
# These need a check for creation on a new volume in start.sh
echo "Validating other directories"
mkdir -p /data/database
mkdir -p /data/var-lib/gvm
mkdir -p /data/var-lib/openvas
mkdir -p /data/var-log/gvm
mkdir -p /data/var-lib/notus
mkdir -p /data/var-lib/mosquitto
mkdir -p /data/var-log/postgresql
mkdir -p /data/var-log/mosquitto
mkdir -p /data/local-share/gvm
mkdir -p /data/var-lib/gvm/cert-data
mkdir -p /data/var-lib/gvm/scap-data
mkdir -p /data/var-lib/gvm/data-objects
mkdir -p /data/var-lib/gvm/private/CA/
mkdir -p /data/var-lib/openvas/plugins
mkdir -p /data/var-lib/gvm/gvmd/gnupg
mkdir -p /data/local-etc/openvas
mkdir -p /data/local-etc/openvas/gnupg
mkdir -p /data/local-etc/gvm

# Create gvm user
echo "Create gvm user"
if !  grep -qis gvm /etc/passwd ; then
	useradd --home-dir /usr/local/share/gvm gvm
fi

# Link the database to the /data folder where the volume should be mounted
echo "Setting up soft links"
if ! [ -d /data/database/base ] && { [ "$1" == "single" ] || [ "$1" == "postgresql" ]; }; then
	echo "Database"
	mv /var/lib/postgresql/13/main/* /data/database/ 
	rm -rf /var/lib/postgresql/13/main
	ln -s /data/database /var/lib/postgresql/13/main
	chown postgres /data/database
	chmod 0700 /data/database
else 
	echo "/data/database/base already exists ..."
	echo " NOT moving data from image to /data"
fi

# Fix up var/lib 
if ! [ -L /usr/local/var/lib ]; then
	echo "/usr/local/var/lib"
	if [ -d /usr/local/var/lib ]; then
		echo "Preserve contents of /usr/local/var/lib"
		cp -rf /usr/local/var/lib/* /data/var-lib/
	fi
	rm -rf /usr/local/var/lib
	ln -s /data/var-lib /usr/local/var/lib
fi

if ! [ -L /usr/local/var/log ]; then 
	echo "/usr/local/var/log"
	# Don't copy over existing log files
	#cp -rf /usr/local/var/log/* /data/var-log/
	rm -rf /usr/local/var/log
	ln -s /data/var-log /usr/local/var/log 
fi
if ! [ -L /var/log ]; then
	echo "/var/log"
	# Don't copy over existing log files ... 
	#cp -rf /var/log/* /data/var-log/
	rm -rf /var/log 
	ln -s /data/var-log /var/log
fi

# Here we make sure the main log directory exists and all
# of the logs we expect are there and the right permissions. 
# This ensure they will get sent to docker via the tail -F 
# at the end of the init script. 
echo "Setting up logs"
mkdir -p /var/log/gvm
for log in gvmd.log  healthchecks.log  notus-scanner.log  openvas.log  ospd-openvas.log  redis-server.log; do
	touch /var/log/gvm/$log
done 
chmod 644 /var/log/gvm/*
chown gvm:gvm /var/log/gvm/gvmd.log

# Fix up local/share
echo "Fixing local/share"
if ! [ -L /usr/local/share ]; then
	cp -rpf /usr/local/share/* /data/local-share
	rm -rf /usr/local/share
	ln -s /data/local-share /usr/local/share
fi

# Fix up run

if ! [ -L /usr/local/var/run ]; then
	echo "Fixing run"
	rm -rf /usr/local/var/run
	ln -s /run  /usr/local/var/run
fi

# Fix up /var/lib/gvm
if ! [ -L /var/lib/gvm ]; then
	echo "Fixing /var/lib/gvm"
	if [ -d /var/lib/gvm ] ; then 
		echo "Preserve contents of /var/lib/gvm"
		cp -rpf /var/lib/gvm/* /data/var-lib/gvm
	fi
	rm -rf /var/lib/gvm
	ln -s /data/var-lib/gvm /var/lib/gvm
fi

# Fix up /var/lib/notus
if ! [ -L /var/lib/notus ]; then
	echo "Fixing /var/lib/notus"
	if [ -d /var/lib/notus ]; then
		echo "Preserve contents of /var/lib/notus"
		cp -rpf /var/lib/notus /data/var/lib/
	fi
	rm -rf /var/lib/notus
	ln -s /data/var-lib/notus /var/lib/notus
fi

# Fix up /var/lib/openvas
if ! [ -L /var/lib/openvas ] && { [ "$1" == "gvmd" ] || [ "$1" == "postgresql" ]; };  then 
	echo "Fixing /var/lib/openvas"
	if [ -d /var/lib/openvas ]; then
		echo "Preserving contents of /var/lib/openvas"
		cp -rpf /var/lib/openvas/* /data/var-lib/openvas
	fi
	rm -rf /var/lib/openvas
	ln -s /data/var-lib/openvas /var/lib/openvas
fi


# Handle the config files for loggin and pw-policy properly
# If there is is version already in /data, then just link to it.
# If no existing config, copy the default there.
# Defaults should be in /usr/local/etc/
# Configs live in sub dirs gvm & openvas
# gvm logging

if ! [ -L /etc/gvm ]; then
	echo "Handling config files"
	cp -rpn /etc/gvm/* /usr/local/etc/gvm/* /data/local-etc/gvm/  2> /dev/null 
	rm -rf /etc/gvm /usr/local/etc/gvm
	ln -s /data/local-etc/gvm /etc/gvm
	ln -s /data/local-etc/gvm /usr/local/etc/gvm
	cp -rpn /etc/openvas/* /usr/local/etc/openvas/* /data/local-etc/openvas/ 2> /dev/null
	rm -rf /etc/openvas /usr/local/etc/openvas
	ln -s /data/local-etc/openvas /etc/openvas
	ln -s /data/local-etc/openvas /usr/local/etc/openvas
fi
echo "Fixing some permissions"
# Fix ownership and permissions
chown -R postgres:postgres /data/database /data/var-log/postgresql /run/postgresql 
chmod 750 /data/database
chmod 770 /run/gvm /run/ospd /var/lib/gvm/gvmd/gnupg /run/gsad
chown -R gvm:gvm  /data/var-lib/openvas /data/local-share/gvm /data/var-log/gvm /data/var-lib/gvm /run/gvm* /run/ospd /run/gsad /etc/openvas/gnupg
chmod 777 /run 
chmod 740 /run/mosquitto /var/log/mosquitto
chown mosquitto /run/mosquitto /var/log/mosquitto 
chown -R postfix:postfix /var/lib/postfix
chown -R gvm:gvm /data/var-lib/notus
echo "All done ... mark the container as setup and ready"
touch /.fs-setup-complete
