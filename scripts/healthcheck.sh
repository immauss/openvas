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


esac
