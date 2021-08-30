#!/usr/bin/env bash
#set -Eeuo pipefail
echo "Choosing container start method from:"
echo "$@"


case $1 in
	gsad)
	echo "Starting Greenbone Security Assitannt !!"
	/scripts/gsad.sh
;;
	gvmd)
	echo "Starting Greenbone Vulnerability Manager daemon !!"
	/scripts/gvmd.sh
;;
	openvas)
	echo "Starting ospd-openvas !!"
	/scripts/openvas.sh
;;
	postgresql)
	echo "Starting postgresql for gvmd !!"
	/scripts/postgresql.sh
;;
	*)
	echo "Starting gvmd & openvas in a single container !!"
	/scripts/single.sh $@
;;

esac