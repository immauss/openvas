#!/usr/bin/env bash

FEED_NAME="Greenbone Community SCAP Feed"
FEED_VENDOR="Greenbone Networks GmbH"
FEED_HOME="https://community.greenbone.net/t/about-greenbone-community-feed-gcf/1224"
SCAP_DIR="/usr/local/var/lib/gvm/scap-data"
TIMESTAMP="$SCAP_DIR/timestamp"

rsync --compress-level=9 --links --times --omit-dir-times --recursive --partial --quiet --delete --exclude feed.xml rsync://feed.openvas.org:/scap-data $SCAP_DIR

if [ -r "$TIMESTAMP" ]; then
  FEED_VERSION=$(cat "$TIMESTAMP")
else
  FEED_VERSION=0
fi

mkdir -p $SCAP_DIR
cat << EOF > $SCAP_DIR/feed.xml
<feed id="6315d194-4b6a-11e7-a570-28d24461215b">
<type>SCAP</type>
<name>$FEED_NAME</name>
<version>$FEED_VERSION</version>
<vendor>$FEED_VENDOR</vendor>
<home>$FEED_HOME</home>
<description>
This script synchronizes a SCAP collection with the '$FEED_NAME'.
The '$FEED_NAME' is provided by '$FEED_VENDOR'.
Online information about this feed: '$FEED_HOME'.
</description>
</feed>
EOF
