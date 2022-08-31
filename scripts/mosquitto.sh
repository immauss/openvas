#!/usr/bin/env bash
rm /run/mosquitto up


# Start the mqtt 
if  ! grep -qis  mosquitto /etc/openvas/openvas.conf; then  
	echo "mqtt_server_uri = 0.0.0.0:1883" |  tee -a /etc/openvas/openvas.conf
        echo -e "listener 1883\nallow_anonymous true" >> /etc/mosquitto.conf
fi

chmod  777 /run/mosquitto
/usr/sbin/mosquitto -c /etc/mosquitto/mosquitto.conf  &

touch /run/mosquittoup

echo "++++++++++++++++"
echo "+ Tailing logs +"
echo "++++++++++++++++"
tail -F /var/log/mosquitto/mosquitto.log
