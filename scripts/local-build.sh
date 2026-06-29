#!/usr/bin/env bash
set -euo pipefail

if [ "${IN_IMMORTALWRT_BUILD_CONTAINER:-0}" != "1" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  WORKDIR="${WORKDIR:-$REPO_ROOT/.build/openwrt-workdir}"
  DEVICE_INPUT="${DEVICE_INPUT:-128M-Ubootmod}"
  DOCKER_BIN="${DOCKER:-docker}"

  mkdir -p "$WORKDIR" "$REPO_ROOT/firmware_collection"

  exec $DOCKER_BIN run --rm --name immortalwrt-local-build \
    -e IN_IMMORTALWRT_BUILD_CONTAINER=1 \
    -e HOST_UID="$(id -u)" \
    -e HOST_GID="$(id -g)" \
    -e DEVICE_INPUT="$DEVICE_INPUT" \
    -e GITHUB_WORKSPACE=/workspace \
    -e TZ="${TZ:-Asia/Shanghai}" \
    -v "$REPO_ROOT":/workspace \
    -v "$WORKDIR":/workdir \
    -w /workspace \
    ubuntu:22.04 /workspace/scripts/local-build.sh
fi

export DEBIAN_FRONTEND=noninteractive
export TZ="${TZ:-Asia/Shanghai}"
export GITHUB_WORKSPACE="${GITHUB_WORKSPACE:-/workspace}"
export DEVICE_INPUT="${DEVICE_INPUT:-128M-Ubootmod}"
export REPO_URL="${REPO_URL:-https://github.com/padavanonly/immortalwrt-mt798x-6.6}"
export REPO_BRANCH="${REPO_BRANCH:-openwrt-24.10-6.6}"
export REPO_COMMIT="${REPO_COMMIT:-}"
export FEEDS_CONF="${FEEDS_CONF:-feeds.conf.default}"
export DIY_P1_SH="${DIY_P1_SH:-diy-part1.sh}"
export DIY_P2_SH="${DIY_P2_SH:-diy-part2.sh}"
export CCACHE_DIR="${CCACHE_DIR:-/workdir/.ccache}"
export CCACHE_MAXSIZE="${CCACHE_MAXSIZE:-2G}"

apt-get -qq update
apt-get -qq install -y --no-install-recommends \
  ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential \
  bzip2 ca-certificates ccache clang cmake cpio curl device-tree-compiler ecj \
  fastjar flex gawk gettext gcc-multilib g++-multilib git gnutls-dev gperf \
  haveged help2man intltool lib32gcc-s1 libc6-dev-i386 libelf-dev libglib2.0-dev \
  libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses-dev libpython3-dev \
  libreadline-dev libssl-dev libtool libyaml-dev libz-dev lld llvm lrzsz mkisofs \
  msmtp nano ninja-build p7zip p7zip-full patch pkgconf python3 python3-pip \
  python3-ply python3-docutils python3-pyelftools qemu-utils re2c rsync scons \
  squashfs-tools subversion swig texinfo uglifyjs unzip vim wget xmlto xxd \
  zlib1g-dev zstd

ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime
echo "$TZ" > /etc/timezone

if ! id builder >/dev/null 2>&1; then
  groupadd -g "${HOST_GID:-1000}" builder 2>/dev/null || true
  useradd -m -u "${HOST_UID:-1000}" -g "${HOST_GID:-1000}" -s /bin/bash builder
fi

mkdir -p /workdir "$CCACHE_DIR" "$GITHUB_WORKSPACE/firmware_collection"
chown -R builder:builder /workdir "$CCACHE_DIR" "$GITHUB_WORKSPACE/firmware_collection"

su builder -c '
set -euo pipefail

cd /workdir
if [ ! -d openwrt/.git ]; then
  git clone "$REPO_URL" -b "$REPO_BRANCH" --single-branch --filter=blob:none openwrt
fi

cd /workdir/openwrt
git fetch origin "$REPO_BRANCH"
git checkout "$REPO_BRANCH"
git reset --hard "origin/$REPO_BRANCH"
if [ -n "$REPO_COMMIT" ]; then
  git checkout "$REPO_COMMIT"
fi

rm -rf \
  package/luci-theme-aurora \
  package/luci-app-aurora-config \
  package/luci-app-bandix \
  package/openwrt-bandix \
  package/vohive \
  package/luci-compat-keep

rm -f \
  files/etc/uci-defaults/93-demogorgon314-badge \
  files/www/luci-static/custom/demogorgon314-badge.js

find build_dir/ -type f \( \
  -path "*/root-*/etc/uci-defaults/93-demogorgon314-badge" -o \
  -path "*/root-*/www/luci-static/custom/demogorgon314-badge.js" \
\) -delete 2>/dev/null || true

find build_dir/ -maxdepth 2 -type d \( \
  -name "luci-app-vohive-*" -o \
  -name "vohive-core-*" \
\) -exec rm -rf {} + 2>/dev/null || true

find bin/packages/ -type f \( \
  -name "luci-app-vohive_*.ipk" -o \
  -name "vohive-core-*.ipk" \
\) -delete 2>/dev/null || true

find build_dir/ -type f \( \
  -path "*/root-*/usr/lib/opkg/info/luci-app-vohive.*" -o \
  -path "*/root-*/usr/share/vohive/*" -o \
  -path "*/root-*/www/luci-static/resources/view/vohive/*" \
\) -delete 2>/dev/null || true

if [ -e "$GITHUB_WORKSPACE/$FEEDS_CONF" ]; then
  cp -f "$GITHUB_WORKSPACE/$FEEDS_CONF" feeds.conf.default
fi

chmod +x "$GITHUB_WORKSPACE/$DIY_P1_SH" "$GITHUB_WORKSPACE/$DIY_P2_SH"
"$GITHUB_WORKSPACE/$DIY_P1_SH"
./scripts/feeds update -a
./scripts/feeds install -a
"$GITHUB_WORKSPACE/$DIY_P2_SH"

ccache --set-config=max_size="$CCACHE_MAXSIZE"
ccache --set-config=cache_dir="$CCACHE_DIR"
ccache --set-config=compression=true
ccache -z

case "$DEVICE_INPUT" in
  "128M") DEVICES="128M" ;;
  "128M-Ubootmod") DEVICES="128M-Ubootmod" ;;
  "all") DEVICES="128M 128M-Ubootmod" ;;
  *) echo "Unknown DEVICE_INPUT: $DEVICE_INPUT" >&2; exit 2 ;;
esac

find bin/targets/ -type f \( \
  -name "*factory.bin" -o \
  -name "*initramfs*" -o \
  -name "*sysupgrade.bin" -o \
  -name "*.manifest" \
\) -delete 2>/dev/null || true

for DEV in $DEVICES; do
  case "$DEV" in
    "128M") CONFIG="config/128m.config" ;;
    "128M-Ubootmod") CONFIG="config/128muboot.config" ;;
  esac

  cp -f "$GITHUB_WORKSPACE/$CONFIG" .config
  make defconfig
  make download -j"$(nproc)"
  if ! make -j"$(nproc)" CC="ccache gcc" CXX="ccache g++"; then
    make -j1 V=s
  fi
done

rm -f "$GITHUB_WORKSPACE/firmware_collection"/*.bin
firmware_filename() {
  local filename="$1"
  local dts=""
  local ubi_size=""

  case "$filename" in
    *cudy_tr3000-v1-ubootmod-squashfs-sysupgrade.bin)
      dts="target/linux/mediatek/dts/mt7981b-cudy-tr3000-v1-ubootmod.dts"
      ;;
  esac

  if [ -n "$dts" ] && [ -f "$dts" ]; then
    ubi_size="$(sed -n 's/.*model = ".*ubi \([0-9][0-9]*[Mm]\)".*/\1/p' "$dts" | head -n 1 | tr '[:upper:]' '[:lower:]')"
  fi

  if [ -n "$ubi_size" ]; then
    filename="${filename/-squashfs-/-ubi${ubi_size}-squashfs-}"
  fi

  printf "%s\n" "$filename"
}

find bin/targets/ -name "*sysupgrade.bin" -print0 | while IFS= read -r -d "" artifact; do
  filename="$(firmware_filename "$(basename "$artifact")")"
  cp -f "$artifact" "$GITHUB_WORKSPACE/firmware_collection/$filename"
done
ccache -s
'
