#!/bin/bash
set -Eeuo pipefail

# This sets up apt-get to not install any documentation.
echo 'force-unsafe-io' > /etc/dpkg/dpkg.cfg.d/02apt-speed \
&& printf '%s\n' \
'path-exclude /usr/share/doc/*' \
'path-exclude /usr/share/man/*' \
'path-exclude /usr/share/groff/*' \
'path-exclude /usr/share/info/*' \
'path-exclude /usr/share/lintian/*' \
'path-exclude /usr/share/linda/*' \
'path-exclude /usr/share/locale/*' \
'path-include /usr/share/locale/en*' \
> /etc/dpkg/dpkg.cfg.d/01_nodoc

export DEBIAN_FRONTEND=noninteractive
export LANG=C.UTF-8

apt-get update
apt-get install -y --no-install-recommends gnupg curl apt-utils ca-certificates
/usr/sbin/update-ca-certificates --fresh

curl -f -L https://www.greenbone.net/GBCommunitySigningKey.asc -o /tmp/GBCommunitySigningKey.asc
gpg --import /tmp/GBCommunitySigningKey.asc
echo "8AE4BE429B60A59B311C2E739823FAA60ED1E580:6:" | gpg --import-ownertrust

# Add the PostgreSQL APT repo for your Debian release
# Import PGDG key
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
  | gpg --dearmor > /usr/share/keyrings/postgresql.gpg

# Add PGDG repo for Debian 12 "bookworm"
echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] \
http://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" \
  > /etc/apt/sources.list.d/pgdg.list

apt-get update 
apt-get upgrade --no-install-recommends -y
echo "install required packages"
PACKAGES=$(cat scripts/package-list)
apt-get install -yq --no-install-recommends $PACKAGES

# Newer version of impacket than available via apt
python3 -m pip install --break-system-packages impacket
ln -s /usr/local/bin/wmiexec.py /usr/local/bin/impacket-wmiexec

# add the gvm users
echo "Creating GVM system user and group"
useradd -r -M -U -G sudo  gvm

#Clean up after apt
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
rm -rf /usr/share/doc/* /usr/share/man/* /usr/share/info/* /usr/share/lintian/* /usr/share/locale/*

#Remove the blank database
rm -rf /var/lib/postgresql/*






