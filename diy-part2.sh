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
# This upstream snapshot stores the ifdown symlink as a literal "ifup" file.
# Restore it so netifd and the tunnel service can actually stop interfaces.
ifdown_path=package/network/config/netifd/files/sbin/ifdown
if [ ! -L "$ifdown_path" ] && [ "$(cat "$ifdown_path")" = ifup ]; then
  rm "$ifdown_path"
  ln -s ifup "$ifdown_path"
fi

#sed -i 's/192.168.1.1/192.168.50.5/g' package/base-files/files/bin/config_generate

# Modify default theme
#sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# Modify hostname
#sed -i 's/OpenWrt/P3TERX-Router/g' package/base-files/files/bin/config_generate

# 临时解决Rust问题
sed -i 's/ci-llvm=true/ci-llvm=false/g' feeds/packages/lang/rust/Makefile

bash "$(dirname "$(readlink -f "$0")")/scripts/prepare-passwall2-golang.sh"

# add date in output file name
sed -i -e '/^IMG_PREFIX:=/i BUILD_DATE := $(shell date +%Y%m%d)' \
       -e '/^IMG_PREFIX:=/ s/\($(SUBTARGET)\)/\1-$(BUILD_DATE)/' include/image.mk

# Add a firmware link below the overview firmware version.
STATUS_SYSTEM_JS="feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/10_system.js"
if [ -f "$STATUS_SYSTEM_JS" ]; then
  sed -i "s#_('Firmware Version'), (L.isObject(boardinfo.release) ? boardinfo.release.description + ' / ' : '') + (luciversion || ''),#_('Firmware Version'), (L.isObject(boardinfo.release) ? boardinfo.release.description + ' / ' : '') + (luciversion || ''),\\n\\t\\t\\t'固件地址', E('a', { href: 'https://github.com/Demogorgon314/immortalwrt-mt7981-cudy-tr3000/releases', target: '_blank', rel: 'noopener noreferrer' }, [ 'https://github.com/Demogorgon314/immortalwrt-mt7981-cudy-tr3000/releases' ]),#" "$STATUS_SYSTEM_JS"
fi

# set ubi to 122M
# sed -i 's/reg = <0x5c0000 0x7000000>;/reg = <0x5c0000 0x7a40000>;/' target/linux/mediatek/dts/mt7981b-cudy-tr3000-v1-ubootmod.dts

# Set hostname without changing LAN IP or network layout.
mkdir -p files/etc/uci-defaults
cat > files/etc/uci-defaults/90-cudyx-defaults <<'EOF_CUDYX'
#!/bin/sh
uci set system.@system[0].hostname='CudyX'
uci commit system
exit 0
EOF_CUDYX
chmod +x files/etc/uci-defaults/90-cudyx-defaults
