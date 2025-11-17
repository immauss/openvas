#!/bin/bash
set -Eeuo pipefail
# Source this for the latest release versions
. build.rc
. build.d/env.sh
echo "Building openvas_scanner"   
cd /build
wget --no-verbose https://github.com/greenbone/openvas-scanner/archive/$openvas.tar.gz
tar -zxf $openvas.tar.gz
cd /build/*/
# Install dev dependency
apt install -y libkrb5-dev libmagic-dev
if [ $(arch) == "armv7l" ]; then
	sed -i "s/%lu/%i/g" src/attack.c
fi
mkdir build
cd build

cmake -DCMAKE_BUILD_TYPE=Release ..
#cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS="-g3" -DCMAKE_CXX_FLAGS="-g3" ..
make #-j$(nproc)
make install
# install rust to build openvas
cd ..
curl -o rustup.sh https://sh.rustup.rs
bash ./rustup.sh -y
. "$HOME/.cargo/env"   
# Build openvasd
cd rust/src/openvasd
cargo build --release
cd ../scannerctl
cargo build --release
echo "Copy openvasd binaries to $INSTALL_ROOT"
cp -v ../../target/release/openvasd $INSTALL_ROOT/bin/
cp -v ../../target/release/scannerctl $INSTALL_ROOT/bin/
mkdir -p ${INSTALL_ROOT}etc/redis/
cp -v ../../../config/redis-openvas.conf $INSTALL_ROOT/etc/redis/
cd /build
rm -rf *
