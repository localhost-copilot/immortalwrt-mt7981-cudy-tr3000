#!/usr/bin/env bash
set -euo pipefail
# geoview 0.2.8 requires Go >= 1.25; the 24.10 feed still ships Go 1.23.
revision=f763390ff284e27572405b1b043366303c471c74
checkout=tmp/passwall2-golang-source
mkdir -p "$checkout"
git -C "$checkout" init -q
git -C "$checkout" fetch -q --depth 1 https://github.com/openwrt/packages.git "$revision"
rm -rf feeds/packages/lang/golang
git -C "$checkout" archive FETCH_HEAD lang/golang | tar -x -C feeds/packages
# Git archive preserves commit timestamps, which can predate cached metadata
# for the replaced Go 1.23 recipe (including its now-removed Config.in).
find feeds/packages/lang/golang -name Makefile -exec touch {} +
# The additional versioned Go host packages need their feed index/install links.
./scripts/feeds update -i packages
./scripts/feeds install -a -p packages
