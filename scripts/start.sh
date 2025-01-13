#!/usr/bin/env bash
#set -Eeuo pipefail
echo "starting container ver $(cat /ver.current) at: $(date)"
if ! [ -f /.fs-setup-complete ]; then
	echo "Setting up container filesystem"
	/scripts/fs-setup.sh $1   # passing this here so only single & postgresql mv the DB files.
elif [ -z $1 ]; then  # We check for this as in multi-container or kubernets, 
                # this will nuke the sockets on the shared volume
				# Which is bad. 
	echo "Looks like this container has already been started once."
	echo "Just doing a little cleanup instead of the whole fs-setup."
	ls -l /.fs-setup-complete
        # we assume it has run already so let's make sure there are no
        # existing pid and sock files to cause issues.
		echo "removing Socket files .... "
        find / -iname "*.sock" -exec rm -f {} \;
		echo "removing pids"
	    find /run -iname "*.pid" -exec rm -f {} \;
fi

echo "Choosing container start method from:"
if [ -z $1 ] ; then
	echo " Nothing ... so we start in the default of single container mode"
else
	echo "$@"
fi
# We'll use this later to know how to check container health
echo "$1" > /usr/local/etc/running-as

sorry() {
	echo " Sorry.. this version not ready for multi-container."
	echo " Check https://github.com/immauss/openvas for latest news."
	echo " Sleeping for 30 days instead of just restarting." 
	echo " You should use a different tag. " 
	sleep 30d
}

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
	notus)
	echo "Starting notus-scanner !!"
	exec /scripts/notus-scanner.sh
;;
	postgresql)
	echo "Starting postgresql for gvmd !!"
	exec /scripts/postgresql.sh
;;
	redis)
	echo "Starting redis !!"
	exec /scripts/redis.sh
;;
	mosquitto)
	echo "Starting the mosquitto !!"
	exec /scripts/mosquitto.sh 
;;
	remote)
	echo "Start remote scanner !!"
	exec /scripts/remote-scanner.sh
;;
	debug)
	echo "Starting bash shell!!"
	/bin/bash -c "sleep 30d"
;;
	*)
	echo "Starting gvmd & openvas in a single container !!"
	echo "single" > /usr/local/etc/running-as
	exec /scripts/single.sh $@
;;

esac
