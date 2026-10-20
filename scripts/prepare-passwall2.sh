#!/usr/bin/env bash
set -euo pipefail

# Run from the OpenWrt source tree. Never pass private GitHub credentials to
# the build container: export the pinned local checkout on the host instead.
RECIPE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASSWALL2_REV=ac3c9850bd6ee33972f84d1bb71226c50d5f399c
PASSWALL_PACKAGES_REV=a6e290333b392671678781d1a629d22c6510b6fd
source_dir="${PASSWALL2_SOURCE:?Set PASSWALL2_SOURCE to the authenticated private checkout}"
test "$(git -C "$source_dir" rev-parse HEAD)" = "$PASSWALL2_REV"
mkdir -p package/luci-app-passwall2
git -C "$source_dir" archive "$PASSWALL2_REV:luci-app-passwall2" | tar -x -C package/luci-app-passwall2
touch package/luci-app-passwall2/Makefile
cp -R "$RECIPE_ROOT/packages/xray-core" package/

# First feed wins where upstream also carries these package names. The Xray
# recipe above takes precedence over feeds and pins the tested binary.
sed -i '/^src-git passwall_packages /d' feeds.conf.default
{ printf 'src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git^%s\n' "$PASSWALL_PACKAGES_REV"; cat feeds.conf.default; } > feeds.conf.passwall2
mv feeds.conf.passwall2 feeds.conf.default
mkdir -p files
cp -R "$RECIPE_ROOT/files/." files/
