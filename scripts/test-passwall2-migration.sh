#!/bin/sh
# Run only in a disposable OpenWrt container with NET_ADMIN, nft, Lua and UCI.
# Mount the firmware recipe at /recipe and the private fork at /passwall2-source.
set -eu
test -f /.dockerenv
# The container skips OpenWrt's normal board configuration generation.
touch /etc/config/system
fork=/passwall2-source/luci-app-passwall2
mkdir -p /usr/lib/lua/luci/passwall2 /usr/share/passwall2 /etc/passwall2 /var/lock
cp "$fork/luasrc/passwall2/kill_switch.lua" /usr/lib/lua/luci/passwall2/
cp "$fork/root/usr/share/passwall2/kill_switch.lua" /usr/share/passwall2/
cp "$fork/root/usr/share/passwall2/kill_switch.sh" /usr/share/passwall2/
cp "$fork/root/usr/share/passwall2/0_default_config" /usr/share/passwall2/
cp "$fork/root/etc/init.d/passwall2_guard" /etc/init.d/
chmod +x /usr/share/passwall2/kill_switch.sh /etc/init.d/passwall2_guard
printf '#!/bin/sh\nexit 0\n' > /etc/init.d/passwall2
chmod +x /etc/init.d/passwall2
mkdir -p /usr/share/nftables.d/ruleset-post

sh /recipe/files/etc/uci-defaults/99-passwall2-dedicated
test "$(uci get passwall2.@global[0].kill_switch)" = 1
test "$(uci get passwall2.@global_app[0].xray_file)" = /usr/bin/xray
nft list table inet passwall2_guard | grep -q 'policy drop'
echo 'Fresh install: default deny guard and packaged Xray selected'

uci set passwall2.test_node=nodes
uci set passwall2.test_node.type=Xray
uci set passwall2.test_node.address=203.0.113.10
uci set passwall2.test_node.port=443
uci set passwall2.test_node.uuid=preserved-test-value
uci set passwall2.@global[0].node=test_node
uci set passwall2.@global_app[0].xray_file=/etc/att-proxy/old-xray
uci commit passwall2
touch /usr/share/nftables.d/ruleset-post/91-att-proxy.nft
nft add table inet att_proxy
sh /recipe/files/etc/uci-defaults/99-passwall2-dedicated
test "$(uci get passwall2.test_node.uuid)" = preserved-test-value
test "$(uci get passwall2.@global[0].node)" = test_node
test -f /etc/passwall2/legacy/91-att-proxy.nft.disabled
! nft list table inet att_proxy 2>/dev/null
nft list table inet passwall2_guard | grep -q '203.0.113.10'
echo 'Upgrade: node retained, new guard active, old guard retired'

touch /usr/share/nftables.d/ruleset-post/91-att-proxy.nft
nft add table inet att_proxy
printf '#!/bin/sh\nexit 1\n' > /usr/share/passwall2/kill_switch.sh
if sh /recipe/files/etc/uci-defaults/99-passwall2-dedicated; then
    echo 'Migration incorrectly succeeded without guard' >&2
    exit 1
fi
test -f /usr/share/nftables.d/ruleset-post/91-att-proxy.nft
nft list table inet att_proxy >/dev/null
echo 'Failed guard activation: migration preserves old protection'
