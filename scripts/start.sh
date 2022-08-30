#!/usr/bin/env bash
#set -Eeuo pipefail
if ! [ -f /.fs-setup-complete ]; then
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

sorry() {
	echo " Sorry.. this version not ready for multi-container."
	echo " Check https://github.com/immauss/openvas for latest news."
	exit
}

case $1 in
	gsad)
		sorry
	echo "Starting Greenbone Security Assitannt !!"
	exec /scripts/gsad.sh
;;
	gvmd)
		sorry
	echo "Starting Greenbone Vulnerability Manager daemon !!"
	exec /scripts/gvmd.sh
;;
	openvas)
		sorry
	echo "Starting ospd-openvas !!"
	exec /scripts/openvas.sh
;;
	postgresql)
		sorry
	echo "Starting postgresql for gvmd !!"
	exec /scripts/postgresql.sh
;;
	redis)
		sorry
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
