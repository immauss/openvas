#!/usr/bin/env bash
rm /run/mosquittoup


# Start the mqtt 
if  ! grep -qis  allow_anonymous /etc/mosquitto/mosquitto.conf; then  
        echo -e "listener 1883\nallow_anonymous true" >> /etc/mosquitto/mosquitto.conf
fi

chmod  777 /run/mosquitto
/usr/sbin/mosquitto -c /etc/mosquitto/mosquitto.conf  &

touch /run/mosquittoup

echo "++++++++++++++++"
echo "+ Tailing logs +"
echo "++++++++++++++++"
tail -F /var/log/mosquitto/mosquitto.log
