#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Uncomment a feed source
#sed -i 's/^#\(.*helloworld\)/\1/' feeds.conf.default

# Add a feed source
#echo 'src-git helloworld https://github.com/fw876/helloworld' >>feeds.conf.default
#echo 'src-git passwall https://github.com/xiaorouji/openwrt-passwall' >>feeds.conf.default

# Vantage v1.0.12: pin the tested theme and dashboard to the release commit.
sed -i '/^src-git vantage /d' feeds.conf.default
echo 'src-git vantage https://github.com/anothaDev/luci-theme-vantage.git^430e77c0f166f87235289fb45aeda843ca0bdc24' >> feeds.conf.default
git clone https://github.com/timsaya/luci-app-bandix package/luci-app-bandix
git clone https://github.com/timsaya/openwrt-bandix package/openwrt-bandix

# Install the tested custom manager, its dependencies and pinned Xray.
bash "$(dirname "$(readlink -f "$0")")/scripts/prepare-passwall2.sh"
