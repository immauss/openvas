#!/bin/bash 
FUNC=$(cat /usr/local/etc/running-as)

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
		#gsad should be listening on 9392
		curl -f http://localhost:9392/ || curl -kf https://localhost:9392/ || exit 1
	;;
	redis)
		redis-cli -s /run/redis/redis.sock ping || exit 1
	;;
	postgresql)
		# There's probably a pg_ctl command that is better for this.
		nmap -p 5432 localhost| grep -qs "5432.*open" || exit 1
	;;
	single)
		# openvas
		UUID=$( su -c "gvmd --get-scanners" gvm | awk /OpenVAS/'{print  $1}' )
		su -c "gvmd --verify-scanner=$UUID" gvm | grep OpenVAS || FAIL=1
		echo "UNHEATHLY CONTAINER: openvas healthcheck failed."
		# gvmd
		nmap -p 9390 localhost| grep -qs "9390.*open" || FAIL=1
		echo "UNHEALTHY CONTAINER: gvmd healthcheck failed."
		# gsad
		curl -f http://localhost:9392/ || curl -kf https://localhost:9392/ || FAIL=1
		echo "UNHEALTHY CONTAINER: gsad healthcheck failed."
		# redis
		redis-cli -s /run/redis/redis.sock ping || FAIL=1
		echo "UNHEALTHY CONTAINER: redis healthcheck failed."
		# postgresql
		nmap -p 5432 localhost| grep -qs "5432.*open" || FAIL=1
		echo "UNHEALTHY CONTAINER: postgresql healthcheck failed."
		if [ $FAIL -eq 1 ]; then
			echo " HEALTHECHECK FAILED ! ";
			exit 1
		else
			echo " Healthchecks completed with no issues."

		fi	
		


esac
