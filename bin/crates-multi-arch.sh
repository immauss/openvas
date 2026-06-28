#/bin/bash
set -Eeuo pipefail
echo "Starting to build crates for $1"

platform="$1"                 # linux/amd64 or linux/arm64
targetarch="${platform##*/}"   # amd64 or arm64
BUILDHOME="/home/scott/Projects/openvas"
. $BUILDHOME/build.rc

outdir="$BUILDHOME/rust/$targetarch"
stamp="$outdir/$openvas"
mkdir -p "$outdir"

# if [ -s "$outdir/crates.tar" ] && [ -f "$stamp" ]; then
# 	echo "Rust crates already built for $platform / $targetarch / $openvas"
# 	exit 0
# fi

echo "Building OpenVAS Rust dependency bundle for $platform"

workdir="$(mktemp -d "$BUILDHOME/tmp/openvas-rust-${targetarch}.XXXXXX")"
archives_out="$workdir/archives"
mkdir -p "$archives_out"

wget --no-verbose \
	-O "$workdir/openvas-scanner.tar.gz" \
	"https://github.com/greenbone/openvas-scanner/archive/$openvas.tar.gz"

tar -zxf "$workdir/openvas-scanner.tar.gz" -C "$workdir"

srcroot="$(find "$workdir" -mindepth 1 -maxdepth 1 -type d -name 'openvas-scanner-*' | head -n 1)"

if [ -z "$srcroot" ]; then
	echo "Could not find extracted openvas-scanner source tree" >&2
	exit 1
fi

dockerfile_export="$workdir/prod-export.Dockerfile"

cat "$srcroot/.docker/prod.Dockerfile" > "$dockerfile_export"

cat >> "$dockerfile_export" <<'EOF'

FROM scratch AS export-archives
COPY --from=build-archives /archives/ /
EOF

docker buildx build \
	--platform "$platform" \
	--target export-archives \
	-f "$dockerfile_export" \
	--output "type=local,dest=$archives_out" \
	"$srcroot"

rm -rf "$srcroot/rust/crates/nasl-c-lib/build-cache/archives"
mkdir -p "$srcroot/rust/crates/nasl-c-lib/build-cache/archives"

cp -a "$archives_out/." "$srcroot/rust/crates/nasl-c-lib/build-cache/archives/"
touch "$srcroot/rust/crates/nasl-c-lib/build-cache/archives/.stamp"

tar -C "$srcroot/rust" -cf "$outdir/crates.tar" crates

touch "$stamp"

rm -rf "$workdir"




exit

CONTAINER_CMD="/usr/bin/docker"
DOCKERFILE="../../../.docker/prod.Dockerfile"
BUILD_CONTEXT="../../.."
ARCHIVES_DIR="build-cache/archives"
ARCHIVES_STAMP="$ARCHIVES_DIR/.stamp"
container_name=cratebuilder
image_tag=unknown

# Run from "rust/crates/nasl-c-lib"
for Archs in "linux/arm64" "linux/x86_64"; do  
	echo "Using container runtime: $CONTAINER_CMD"; \
	$CONTAINER_CMD build \
		-f $DOCKERFILE \
		--target build-archives \
        --platform="$Archs" \
		-t "$image_tag" \
		$BUILD_CONTEXT; \
	$CONTAINER_CMD create --name "$container_name" "$image_tag" >/dev/null; \
	$CONTAINER_CMD cp "$container_name:/archives/." $ARCHIVES_DIR/; \
	$CONTAINER_CMD rm "$container_name" >/dev/null; \
	$CONTAINER_CMD rmi "$image_tag" >/dev/null; \
	touch $@
done