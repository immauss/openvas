#!/usr/bin/env bash
set -Eeo pipefail
HTTPS=${HTTPS:-false}
GSATIMEOUT=${GSATIMEOUT:-15}
if [ ! -d /usr/local/var/run/ ]; then
	mkdir -p /usr/local/var/run
fi
chown gvm /usr/local/var/run
chown gvm /usr/local/var/log/gvm 

echo "Starting Greenbone Security Assistant..."
#su -c "gsad --verbose --http-only --no-redirect --port=9392" gvm
if [ $HTTPS == "true" ]; then
	su -c "gsad --mlisten ovas_gvmd -m 9390 --verbose --timeout=$GSATIMEOUT \
	            --gnutls-priorities=SECURE128:-AES-128-CBC:-CAMELLIA-128-CBC:-VERS-SSL3.0:-VERS-TLS1.0 \
		    --no-redirect \
		    --port=9392" gvm
else
	su -c "gsad --mlisten ovas_gvmd -m 9390 --verbose --timeout=$GSATIMEOUT --http-only --no-redirect --port=9392" gvm
fi
tail -f /usr/local/var/log/gvm/gsad.log &
wait $!
