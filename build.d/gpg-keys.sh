#!/bin/bash
# Prep the gpg keys
export OPENVAS_GNUPG_HOME=/etc/openvas/gnupg
export GNUPGHOME=/tmp/openvas-gnupg
if ! [ -f tmp/GBCommunitySigningKey.asc ]; then
        echo " Get the Greenbone public Key"
        curl -f -L https://www.greenbone.net/GBCommunitySigningKey.asc -o /etc/GBCommunitySigningKey.asc
        echo "8AE4BE429B60A59B311C2E739823FAA60ED1E580:6:" > /etc/ownertrust.txt
        echo "Setup environment"
        mkdir -m 0600 -p $GNUPGHOME $OPENVAS_GNUPG_HOME
        echo "Import the key "
        gpg --import /etc/GBCommunitySigningKey.asc
        gpg --import-ownertrust < /etc/ownertrust.txt
        echo "Setup key for openvas .."
        cp -r /tmp/openvas-gnupg/* $OPENVAS_GNUPG_HOME/
        #chown -R gvm:gvm $OPENVAS_GNUPG_HOME
fi
