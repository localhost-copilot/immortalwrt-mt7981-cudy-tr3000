#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Modify default IP
#sed -i 's/192.168.1.1/192.168.50.5/g' package/base-files/files/bin/config_generate

# Modify default theme
#sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# Modify hostname
#sed -i 's/OpenWrt/P3TERX-Router/g' package/base-files/files/bin/config_generate

# Enable USB power for Cudy TR3000 by default
sed -i '/modem-power/,/};/{s/gpio-export,output = <1>;/gpio-export,output = <0>;/}' target/linux/mediatek/dts/mt7981b-cudy-tr3000-v1.dtsi

# Add OpenClash Meta
mkdir -p files/etc/openclash/core/clash_meta
META_CORE_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-arm64.tar.gz"
TMP_META_FILE="/tmp/clash_meta.tar.gz"

wget -qO "$TMP_META_FILE" "$META_CORE_URL"
tar -zxvf "$TMP_META_FILE" -C files/etc/openclash/core/clash_meta/
chmod +x files/etc/openclash/core/clash_meta/clash
rm -f "$TMP_META_FILE"
