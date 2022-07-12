#!/usr/bin/env bash
#set -Eeuo pipefail
if ! [ -f /data/.fs-setup-complete ]; then
	echo "Setting up contianer filesystem"
	/scripts/fs-setup.sh
else
        # we assume it has run already so let's make sure there are no
        # existing pid and sock files to cause issues.
        find / -iname "*.sock" -exec rm -f {} \;
        find /run -iname "*.pid" -exec rm -f {} \;
fi

echo "Choosing container start method from:"
echo "$@"
# We'll use this later to know how to check container health
echo "$1" > /usr/local/etc/running-as

case $1 in
	gsad)
	echo "Starting Greenbone Security Assitannt !!"
	exec /scripts/gsad.sh
;;
	gvmd)
	echo "Starting Greenbone Vulnerability Manager daemon !!"
	exec /scripts/gvmd.sh
;;
	openvas)
	echo "Starting ospd-openvas !!"
	exec /scripts/openvas.sh
;;
	postgresql)
	echo "Starting postgresql for gvmd !!"
	exec /scripts/postgresql.sh
;;
	redis)
	echo "Starting redis !!"
	exec /scripts/redis.sh
;;
	debug)
	echo "Starting bash shell!!"
	/bin/bash -c "sleep 30d"
;;
	*)
	echo "Starting gvmd & openvas in a single container !!"
	exec /scripts/single.sh $@
;;

esac
