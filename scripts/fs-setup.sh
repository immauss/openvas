#!/bin/bash 
# This will setup all the links and directories required by the image. 
mkdir -p /run/gvm
mkdir -p /run/ospd
mkdir -p /run/gvmd
mkdir -p /run/redis
mkdir -p /run/gsad
mkdir -p /etc/openvas
mkdir -p /usr/local/var
# These need a check for creation on a new volume in start.sh
mkdir -p /data/database
mkdir -p /data/var-lib/gvm
mkdir -p /data/var-lib/openvas
mkdir -p /data/var-log/gvm
mkdir -p /data/var-log/postgresql
mkdir -p /data/local-share/gvm
mkdir -p /data/var-lib/gvm/cert-data
mkdir -p /data/var-lib/gvm/scap-data
mkdir -p /data/var-lib/gvm/data-objects
mkdir -p /data/var-lib/gvm/private/CA/
mkdir -p /data/var-lib/openvas/plugins
mkdir -p /data/var-lib/gvm/gvmd/gnupg
mkdir -p /data/local-etc/openvas
mkdir -p /data/local-etc/gvm

# Link the database to the /data folder where the volume should be mounted
if ! [ -d /data/database/base ]; then
	mv /var/lib/postgresql/13/main/* /data/database/ 
	rm -rf /var/lib/postgresql/13/main
	ln -s /data/database /var/lib/postgresql/13/main
else 
	echo "/data/database/base alredy exists ..."
	echo " NOT moving data from image to /data"
fi

# Fix up var/lib 
if ! [ -L /var/lib ]; then
	cp -rf /usr/local/var/lib/* /data/var-lib/
	rm -rf /usr/local/var/lib
	ln -s /data/var-lib /usr/local/var/lib
fi
if ! [ -L /usr/local/var/lib ]; then
	cp -rf /var/lib/* /data/var-lib/
	rm -rf /var/lib 
	ln -s /data/var-lib /var/lib
fi
# Fix up var/log
if ! [ -L /usr/local/var/log ]; then 
	# Don't copy over existing log files
	#cp -rf /usr/local/var/log/* /data/var-log/
	rm -rf /usr/local/var/log
	ln -s /data/var-log /usr/local/var/log 
fi
if ! [ -L /var/log ]; then
	# Don't copy over existing log files ... 
	#cp -rf /var/log/* /data/var-log/
	rm -rf /var/log 
	ln -s /data/var-log /var/log
fi

# Fix up local/share
if ! [ -L /usr/local/share ]; then
	cp -rpf /usr/local/share/* /data/local-share
	rm -rf /usr/local/share
	ln -s /data/local-share /usr/local/share
fi

# Fix up run
if ! [ -L /usr/local/var/run ]; then
	rm -rf /usr/local/var/run
	ln -s /run  /usr/local/var/run
fi

# Fix up /var/lib/gvm
if ! [ -L /var/lib/gvm ]; then
	cp -rpf /var/lib/gvm/* /data/var-lib/gvm
	rm -rf /var/lib/gvm
	ln -s /data/var-lib/gvm /var/lib/gvm
fi

# Fix up /var/lib/openvas
if ! [ -L /var/lib/openvas ]; then 
	cp -rpf /var/lib/openvas/* /data/var-lib/openvas
	rm -rf /var/lib/openvas
	ln -s /data/var-lib/openvas /var/lib/openvas
fi
# Create gvm user
if !  grep -qis gvm /etc/passwd ; then
	useradd --home-dir /usr/local/share/gvm gvm
fi

# Handle the config files for loggin and pw-policy properly
# If there is is version already in /data, then just link to it.
# If no existing config, copy the default there.
# Defaults should be in /usr/local/etc/
# Configs live in sub dirs gvm & openvas
# gvm logging
if [ -f /data/local-etc/gvm/gvmd_log.conf ]; then
	echo "Using existing gvm logging config"
else
	echo "Using default gvm logging config"
	cp /usr/local/etc/gvm/gvmd_log.conf /data/local-etc/gvm/
fi
# gvm password policy
if [ -f /data/local-etc/gvm/pwpolicy.conf ]; then
	echo "Using existing password policy config"
else
	echo "Using default gvm logging config"
	cp /usr/local/etc/gvm/pwpolicy.conf /data/local-etc/gvm/
fi

rm -rf /etc/gvm /usr/local/etc/gvm
ln -s /data/local-etc/gvm /etc/gvm
ln -s /data/local-etc/gvm /usr/local/etc/gvm
# openvas logging
if [ -f /data/local-etc/openvas/openvas_log.conf ]; then
	echo "Using existing openvas logging config"
else
	echo "Using default openvas logging config"
	cp /usr/local/etc/openvas/openvas_log.conf /data/local-etc/openvas/
fi

rm -rf /etc/openvas /usr/local/etc/openvas
ln -s /data/local-etc/openvas /etc/openvas
ln -s /data/local-etc/openvas /usr/local/etc/openvas


# Fix ownership and permissions
chown -R postgres:postgres /data/database /data/var-log/postgresql
chmod 750 /data/database
chmod 770 /run/gvm /run/ospd /var/lib/gvm/gvmd/gnupg /run/gsad
chown -R gvm:gvm  /data/var-lib/openvas /data/local-share/gvm /data/var-log/gvm /data/var-lib/gvm /run/gvm* /run/ospd /run/gsad
chmod 777 /run
chown -R postfix:postfix /var/lib/postfix


touch /data/.fs-setup-complete
