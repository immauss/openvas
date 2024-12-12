#!/bin/bash 
SKIPGSAD=${SKIPGSAD:-false}
FUNC=$(cat /usr/local/etc/running-as)
ContainerShutdown() {
	# Flush logs;

	# Kill the tail that holds the container open
	kill $(ps auxw | awk /tail/'{print $2}' )
}

# Check the Disk Space
HIGHROOT=$(df -h / | tr -d % | awk /overlay/'{ if ( $5 > 95 ) print $4}')
ROOTSPC=$(df / | tr -d %| awk /overlay/'{print $4}')	
if ! [ -z $HIGHROOT ]; then
	echo -e "Available Container Disk Space low. (/ = ${HIGHROOT} available).\n if < 100M, container will shutdown." >> /usr/local/var/log/gvm/healthchecks.log
	SERVICE="$SERVICE root disk low\n"
	if [ $ROOTSPC -lt 100000 ]; then
		ContainerShutdown
	fi
fi

HIGHDATA=$(df -h | tr -d % | awk /data/'{ if ( $5 > 95 ) print $4}')		
DATASPC=$(df | tr -d %| awk /data/'{print $4}')	
if ! [ -z $HIGHDATA ]; then
	echo "Available Container Disk Space low. (/data = ${HIGHDATA} available).\n if < 100M, container will shutdown.)" >> /usr/local/var/log/gvm/healthchecks.log
	SERVICE="$SERVICE data disk low\n"
	FAIL=7
	if [ $DATASPC -lt 100000 ]; then
		ContainerShutdown
	fi
fi

case  $FUNC in
	openvas)
		UUID=$( su -c "gvmd --get-scanners" gvm | awk /OpenVAS/'{print  $1}' )
		su -c "gvmd --verify-scanner=$UUID" gvm | grep OpenVAS || exit 1
	;;
	gvmd)
		#gvmd listens on 9390, but not http
		nmap -p 9390 localhost| grep -qs "9390.*open" || exit 1
	;;
	gsad)
		if [ "$SKIPGSAD" == "false" ]; then
			#gsad should be listening on 9392
			curl -f http://localhost:9392/ || curl -kf https://localhost:9392/ || exit 1
		fi
	;;
	redis)
		redis-cli -s /run/redis/redis.sock ping || exit 1
	;;
	postgresql)
		# There's probably a pg_ctl command that is better for this.
		nmap -p 5432 localhost| grep -qs "5432.*open" || exit 1
	;;
	remote)
		FAIL=0		
		# redis
		redis-cli -s /run/redis/redis.sock ping || FAIL=4 
			if [ $FAIL -eq 4 ]; then SERVICE="$SERVICE redis\n"; fi

		if [ $FAIL -ne 0 ]; then
			echo " HEALTHECHECK FAILED !" >> /usr/local/var/log/gvm/healthchecks.log
			echo " These services failed:"  >> /usr/local/var/log/gvm/healthchecks.log
			echo -e "$SERVICE" >> /usr/local/var/log/gvm/healthchecks.log
			exit 1
		else
			echo " Healthchecks completed with no issues." >> /usr/local/var/log/gvm/healthchecks.log

		fi	
		;;
	single)
		FAIL=0
		# gvmd
		nmap -p 9390 localhost| grep -qs "9390.*open" || FAIL=1 
			if [ $FAIL -eq 1 ]; then SERVICE="gvmd\n"; fi
		# openvas
		# Only check openvas if gvmd is running. Otherwise it hangs and then gvmd can't start.
		if [ $FAIL -eq 0 ]; then
			UUID=$( su -c "gvmd --get-scanners" gvm | awk /OpenVAS/'{print  $1}' )
			su -c "gvmd --verify-scanner=$UUID" gvm | grep OpenVAS || FAIL=2 
			if [ $FAIL -eq 2 ]; then SERVICE="$SERVICE openvas\n"; fi	
		else 
			SERVICE="$SERVICE openvas\n"
		fi	
		# gsad
		if [ "$SKIPGSAD" == "false" ]; then
			curl -f http://localhost:9392/ || curl -kf https://localhost:9392/ || FAIL=3 
			if [ $FAIL -eq 3 ]; then SERVICE="$SERVICE gsad\n"; fi
		fi
		# redis
		redis-cli -s /run/redis/redis.sock ping || FAIL=4 
			if [ $FAIL -eq 4 ]; then SERVICE="$SERVICE redis\n"; fi
		# postgresql
		nmap -p 5432 localhost| grep -qs "5432.*open" || FAIL=5 
			if [ $FAIL -eq 5 ]; then SERVICE="$SERVICE postgresql\n"; fi

		if [ $FAIL -ne 0 ]; then
			echo " HEALTHECHECK FAILED !" >> /usr/local/var/log/gvm/healthchecks.log
			echo " These services failed:"  >> /usr/local/var/log/gvm/healthchecks.log
			echo -e "$SERVICE" >> /usr/local/var/log/gvm/healthchecks.log
			exit 1
		else
			echo " Healthchecks completed with no issues." >> /usr/local/var/log/gvm/healthchecks.log

		fi	
		


esac
