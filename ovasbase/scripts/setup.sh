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



install -d /usr/share/postgresql-common/pgdg
curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc
echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt-get bookworm-pgdg main" > /etc/apt/sources.list.d/pdg.list

apt-get update 
apt-get upgrade --no-install-recommends -y
echo "install required packages"
PACKAGES=$(cat scripts/package-list)
apt-get install -yq --no-install-recommends $PACKAGES

# Newer version of impacket than available via apt
python3 -m pip install --break-system-packages impacket
ln -s /usr/local/bin/wmiexec.py /usr/local/bin/impacket-wmiexec

# add the gvm users
useradd -r -M -U -G sudo -s /usr/sbin/nologin gvm



#Clean up after apt
rm -rf /var/lib/apt/lists/*






