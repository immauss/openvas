#!/bin/bash
set -Eeuo pipefail
bash ./build.d/build-prereqs.sh
bash ./build.d/update-certs.sh
bash ./build.d/gvm-libs.sh
bash ./build.d/openvas-smb.sh
bash ./build.d/gvmd.sh
bash ./build.d/openvas-scanner.sh
bash ./build.d/gsa.sh
bash ./build.d/ospd-openvas.sh
bash ./build.d/gvm-tool.sh
bash ./build.d/notus-scanner.sh
bash ./build.d/pg-gvm.sh
bash ./build.d/links.sh
