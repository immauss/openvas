# Respect caller overrides (Dockerfile sets these)
export PREFIX="usr/local/"
export DESTDIR="/artifacts/"
export INSTALL_ROOT="${DESTDIR}/${PREFIX}"
export CMAKE_INSTALL_PREFIX="$INSTALL_ROOT"

# Ensure staging dirs exist
mkdir -p "$INSTALL_ROOT" \
"$DESTDIR/etc" \
"$DESTDIR/usr/lib/systemd/system"

if ! [ -L $DESTDIR/lib ]; then
    cd $DESTDIR
    pwd
    ln -s usr/lib/ ./lib
fi

# Make staged tools/libs discoverable by later steps (if needed)
export PATH="$INSTALL_ROOT/bin:${PATH:-}"
export PKG_CONFIG_PATH="$INSTALL_ROOT/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
export LD_LIBRARY_PATH="$INSTALL_ROOT/lib:${LD_LIBRARY_PATH:-}"