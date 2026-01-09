#!/bin/bash
INSTALL_DIR="/usr/local/"
set -Eeuo pipefail

. build.rc
. build.d/env.sh

apt-get update

echo "Building pg-gvm"
cd /build
wget --no-verbose "https://github.com/greenbone/pg-gvm/archive/$pg_gvm.tar.gz"
tar -zxf "$pg_gvm.tar.gz"

cd /build/*/      # e.g. /build/pg-gvm-22.6.12
mkdir -p build
cd build

for PGVER in 13 15; do
  echo "Building pg-gvm for postgresql-${PGVER}"

  apt-get install -y "postgresql-server-dev-${PGVER}"

  # Make sure we pick the correct pg_config for this build
  export PATH="/usr/lib/postgresql/${PGVER}/bin:${PATH}"

  # Tell CMake explicitly which pg_config to use (matches find_program(PGCONFIG))
  PGCONFIG_BIN="/usr/lib/postgresql/${PGVER}/bin/pg_config"

  # Start with a clean build dir for this version
  rm -rf "build-pg${PGVER}"

  echo "=== Configuring pg-gvm for PostgreSQL ${PGVER} ==="
  cmake -B "build-pg${PGVER}" -S .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DPostgreSQL_TYPE_INCLUDE_DIR="/usr/include/postgresql/${PGVER}/server" \
    -DPGCONFIG="${PGCONFIG_BIN}" \
    -DCMAKE_C_FLAGS="-I/usr/include/postgresql/${PGVER}/server"

  echo "=== Building pg-gvm for PostgreSQL ${PGVER} ==="
  cmake --build "build-pg${PGVER}"

  echo "=== Installing pg-gvm for PostgreSQL ${PGVER} ==="
  cmake --install "build-pg${PGVER}"
done

cd /build
rm -rf *
