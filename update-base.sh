#!/bin/bash
set -Eeuo pipefail
echo "Updating base data"
curl --url https://www.immauss.com/openvas/base.sql.xz -o /usr/lib/base.sql.xz
curl --url https://www.immauss.com/openvas/var-lib.tar.xz -o /usr/lib/var-lib.tar.xz
# Today
