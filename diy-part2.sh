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

# 临时解决Rust问题
sed -i 's/ci-llvm=true/ci-llvm=false/g' feeds/packages/lang/rust/Makefile

# add date in output file name
sed -i -e '/^IMG_PREFIX:=/i BUILD_DATE := $(shell date +%Y%m%d)' \
       -e '/^IMG_PREFIX:=/ s/\($(SUBTARGET)\)/\1-$(BUILD_DATE)/' include/image.mk

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

# Demogorgon314 LuCI badge.
mkdir -p files/www/luci-static/custom
cat > files/www/luci-static/custom/demogorgon314-badge.js <<'EOF_BADGE_JS'
(function () {
  function isFooterNode(node) {
    var el = node.parentElement;
    while (el) {
      var id = (el.id || '').toLowerCase();
      var cls = (el.className || '').toString().toLowerCase();
      if (el.tagName === 'FOOTER' || id.indexOf('footer') >= 0 || cls.indexOf('footer') >= 0) return true;
      el = el.parentElement;
    }
    return false;
  }

  function walkTextNodes(root, callback) {
    var walker = document.createTreeWalker(root || document.body, NodeFilter.SHOW_TEXT, {
      acceptNode: function (node) {
        if (!node.nodeValue || !node.nodeValue.trim()) return NodeFilter.FILTER_REJECT;
        var p = node.parentElement;
        if (!p) return NodeFilter.FILTER_REJECT;
        var tag = p.tagName;
        if (tag === 'SCRIPT' || tag === 'STYLE' || tag === 'TEXTAREA' || tag === 'INPUT') return NodeFilter.FILTER_REJECT;
        return NodeFilter.FILTER_ACCEPT;
      }
    });
    var nodes = [];
    while (walker.nextNode()) nodes.push(walker.currentNode);
    nodes.forEach(callback);
  }

  function patchLuCIText() {
    walkTextNodes(document.body, function (node) {
      var text = node.nodeValue;

      if (text.indexOf('Powered by LuCI') >= 0) {
        node.nodeValue = text.replace('Powered by LuCI', 'Power By Demogorgon314');
        return;
      }

      if (!isFooterNode(node) && text.indexOf('ImmortalWrt') >= 0 && text.indexOf('Powered by') < 0) {
        node.nodeValue = 'Demogorgon314 X VoHive';
      }
    });
  }

  function addBadge() {
    if (!document.getElementById('demogorgon314-badge')) {
      var a = document.createElement('a');
      a.id = 'demogorgon314-badge';
      a.textContent = 'Demogorgon314';
      a.href = 'https://github.com/Demogorgon314/immortalwrt-mt7981-cudy-tr3000';
      a.target = '_blank';
      a.rel = 'noopener noreferrer';
      a.style.cssText = [
        'position:fixed','right:14px','bottom:14px','z-index:99999',
        'padding:6px 10px','border-radius:999px','font-size:12px',
        'line-height:1','text-decoration:none','background:rgba(0,0,0,.62)',
        'color:#fff','box-shadow:0 2px 10px rgba(0,0,0,.25)',
        'backdrop-filter:blur(6px)'
      ].join(';');
      document.body.appendChild(a);
    }
    patchLuCIText();
    setTimeout(patchLuCIText, 300);
    setTimeout(patchLuCIText, 1000);
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', addBadge);
  else addBadge();
})();
EOF_BADGE_JS

cat > files/etc/uci-defaults/93-demogorgon314-badge <<'EOF_BADGE_UCI'
#!/bin/sh
set -e
for f in /usr/share/ucode/luci/template/themes/*/header.ut /usr/lib/lua/luci/view/themes/*/header.htm; do
  [ -f "$f" ] || continue
  grep -q 'demogorgon314-badge.js' "$f" && continue
  if grep -q '</body>' "$f"; then
    sed -i 's#</body>#<script src="/luci-static/custom/demogorgon314-badge.js"></script></body>#' "$f"
  else
    printf '\n<script src="/luci-static/custom/demogorgon314-badge.js"></script>\n' >> "$f"
  fi
done
exit 0
EOF_BADGE_UCI
chmod +x files/etc/uci-defaults/93-demogorgon314-badge
