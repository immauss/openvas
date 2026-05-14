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

# OK ... the AI recommended I add this bit here to fix the FUP from Greenbone in the rust build. 
# most likely because they are using older versions of something from their rust build platform
# and I'm pulling the most recent. 
# BUILDDIR=$(pwd)
# cd rust/crates/nasl-c-lib/libgcrypt-sys
# sh -x ./install-gcrypt.sh
# cd $BUILDDIR
# Install dev dependency
apt install -y libkrb5-dev libmagic-dev capnproto libclang-dev libpcap-dev libsnmp-dev libssl-dev

mkdir build
cd build

cmake -DCMAKE_BUILD_TYPE=Release ..
#cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS="-g3" -DCMAKE_CXX_FLAGS="-g3" ..
make #-j$(nproc)
make install
# install rust to build openvas
cd ..
export RUST_BACKTRACE=full
export CARGO_PROFILE_RELEASE_BUILD_OVERRIDE_DEBUG=true 
CFLAGS="-fcommon"
CPPFLAGS="-fcommon"
curl -o rustup.sh https://sh.rustup.rs
bash ./rustup.sh -y
. "$HOME/.cargo/env"   
# Build openvasd
cd rust/ #src/openvasd
cargo build --release -vv
#cd ../scannerctl
#cargo build --release
echo "#####################################################"
echo "#####################################################"
echo "#####################################################"
find / -name openvasd
find / -name scannerctl
find / -name redis-openvas.conf
echo "#####################################################"
echo "#####################################################"
echo "#####################################################"
echo "Copy openvasd binaries to $INSTALL_ROOT"
cp -v ./target/release/openvasd $INSTALL_ROOT/bin/
cp -v ./target/release/scannerctl $INSTALL_ROOT/bin/
mkdir -p ${INSTALL_ROOT}etc/redis/
cp -v ../config/redis-openvas.conf $INSTALL_ROOT/etc/redis/
cd /build
rm -rf *
