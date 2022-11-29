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
		FAIL=0
		# openvas
		UUID=$( su -c "gvmd --get-scanners" gvm | awk /OpenVAS/'{print  $1}' )
		su -c "gvmd --verify-scanner=$UUID" gvm | grep OpenVAS || FAIL=1 
			if [ $FAIL -eq 1 ]; then SERVCE="openas"; fi
		# gvmd
		nmap -p 9390 localhost| grep -qs "9390.*open" || FAIL=2 
			if [ $FAIL -eq 2 ]; then SERVICE="$SERVICE gvmd"; fi
		# gsad
		curl -f http://localhost:9392/ || curl -kf https://localhost:9392/ || FAIL=3 
			if [ $FAIL -eq 3 ]; then SERVICE="$SERVICE gsad"; fi
		# redis
		redis-cli -s /run/redis/redis.sock ping || FAIL=4 
			if [ $FAIL -eq 4 ]; then SERVICE="$SERVICE redis"; fi
		# postgresql
		nmap -p 5432 localhost| grep -qs "5432.*open" || FAIL=5 
			if [ $FAIL -eq 5 ]; then SERVICE="$SERVICE postgresql"; fi
		if [ $FAIL -ne 0 ]; then
			echo " HEALTHECHECK FAILED ! " >> /usr/local/var/log/gvm/healthchecks.log
			echo " These services failed"  >> /usr/local/var/log/gvm/healthchecks.log
			echo " $SERVICE" >> /usr/local/var/log/gvm/healthchecks.log
			exit 1
		else
			echo " Healthchecks completed with no issues." >> /usr/local/var/log/gvm/healthchecks.log

		fi	
		


esac
