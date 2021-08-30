#!/usr/bin/env bash
set -Eeuo pipefail
HTTPS=${HTTPS:-false}
GSATIMEOUT=${GSATIMEOUT:-15}

echo "Starting Greenbone Security Assistant..."
#su -c "gsad --verbose --http-only --no-redirect --port=9392" gvm
if [ $HTTPS == "true" ]; then
	su -c "gsad --mlisten 127.0.0.1 -m 9390 --verbose --timeout=$GSATIMEOUT \
	            --gnutls-priorities=SECURE128:-AES-128-CBC:-CAMELLIA-128-CBC:-VERS-SSL3.0:-VERS-TLS1.0 \
		    --no-redirect \
		    --port=9392" gvm
else
	su -c "gsad --mlisten 127.0.0.1 -m 9390 --verbose --timeout=$GSATIMEOUT --http-only --no-redirect --port=9392" gvm
fi

wait $!