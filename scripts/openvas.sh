#!/usr/bin/env bash
set -Eeo pipefail
# These are  needed for a first run WITH a new container image
# and an existing database in the mounted volume at /data

if [ ! -L /var/lib/postgresql/12/main ]; then
        echo "Fixing Database folder..."
        rm -rf /var/lib/postgresql/12/main
        ln -s /data/database /var/lib/postgresql/12/main
        chown postgres:postgres -R /data/database
fi
if [ ! -d /usr/local/var/lib ]; then
        mkdir -p /usr/local/var/lib/gsm
        mkdir -p /usr/local/var/lib/openvas
        mkdir -p /usr/local/var/log/gvm
fi
if [ ! -L /usr/local/var/lib  ]; then
        echo "Fixing local/var/lib ... "
        if [ ! -d /data/var-lib ]; then
                mkdir /data/var-lib
        fi
        rm -rf /usr/local/var/lib
        ln -s /data/var-lib /usr/local/var/lib
fi
if [ ! -L /usr/local/share ]; then
        echo "Fixing local/share ... "
        if [ ! -d /data/local-share ]; then mkdir /data/local-share; fi
        rm -rf /usr/local/share
        ln -s /data/local-share /usr/local/share
fi

if [ ! -L /usr/local/var/log/gvm ]; then
        echo "Fixing log directory for persistent logs .... "
        if [ ! -d /data/var-log/ ]; then mkdir /data/var-log; fi
        rm -rf /usr/local/var/log/gvm
        ln -s /data/var-log /usr/local/var/log/gvm
        chown gvm /data/var-log
fi

if [ -f /var/run/ospd/ospd.pid ]; then
		rm -f /var/run/ospd/ospd.pid
fi
touch /usr/local/var/log/gvm/o*.log
tail -f /usr/local/var/log/gvm/o*.log &

echo "Starting Open Scanner Protocol daemon for OpenVAS..."
exec ospd-openvas --log-file /usr/local/var/log/gvm/ospd-openvas.log \
             --unix-socket /run/ospd/ospd.sock --log-level INFO --socket-mode 777 -f



# We run ospd-openvas in the container as root. This way we don't need sudo.
# But if we leave the socket owned by root, gvmd can not communicate with it.
#chgrp gvm /run/ospd/ospd.sock
#tail -f /usr/local/var/log/gvm/o*.log
#wait $!
