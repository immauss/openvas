#!/usr/bin/env bash

FEED_NAME="Greenbone Community CERT Feed"
FEED_VENDOR="Greenbone Networks GmbH"
FEED_HOME="https://community.greenbone.net/t/about-greenbone-community-feed-gcf/1224"
CERT_DIR="/usr/local/var/lib/gvm/cert-data"
TIMESTAMP="$CERT_DIR/timestamp"

rsync --compress-level=9 --links --times --omit-dir-times --recursive --partial --quiet --delete --exclude feed.xml rsync://feed.openvas.org:/cert-data $CERT_DIR

if [ -r "$TIMESTAMP" ]; then
  FEED_VERSION=$(cat "$TIMESTAMP")
else
  FEED_VERSION=0
fi

mkdir -p $CERT_DIR
cat << EOF > $CERT_DIR/feed.xml
<feed id="6315d194-4b6a-11e7-a570-28d24461215b">
<type>CERT</type>
<name>$FEED_NAME</name>
<version>$FEED_VERSION</version>
<vendor>$FEED_VENDOR</vendor>
<home>$FEED_HOME</home>
<description>
This script synchronizes a CERT collection with the '$FEED_NAME'.
The '$FEED_NAME' is provided by '$FEED_VENDOR'.
Online information about this feed: '$FEED_HOME'.
</description>
</feed>
EOF
