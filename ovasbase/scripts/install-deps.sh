#!/bin/bash
set -Eeuo pipefail
echo "install curl"

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
apt-get install -y --no-install-recommends gnupg curl wget apt-utils

echo "Install the postgres repo"
#echo "deb http://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" > /etc/apt/sources.list.d/pgdg.list

apt install curl ca-certificates
install -d /usr/share/postgresql-common/pgdg
curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc
echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" > /etc/apt/sources.list.d/pdg.list

apt-get update 
apt-get upgrade --no-install-recommends -y
echo "install required packages"
PACKAGES=$(cat scripts/package-list)
apt-get install -yq --no-install-recommends $PACKAGES
/usr/sbin/update-ca-certificates --fresh
# Newer version of impacket than available via apt
python3 -m pip install --break-system-packages impacket
ln -s /usr/local/bin/wmiexec.py /usr/local/bin/impacket-wmiexec
#Clean up after apt
rm -rf /var/lib/apt/lists/*






