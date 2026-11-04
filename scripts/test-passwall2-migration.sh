#!/bin/sh
# Run only in a disposable OpenWrt container with NET_ADMIN, nft, Lua and UCI.
# Mount the firmware recipe at /recipe and the public fork at /passwall2-source.
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
cp "$fork/root/usr/share/nftables.d/ruleset-post/92-passwall2-guard.nft" /usr/share/nftables.d/ruleset-post/
cp /recipe/files/lib/upgrade/keep.d/passwall2-dedicated /lib/upgrade/keep.d/

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
uci set passwall2.@global[0].kill_switch=0
uci commit passwall2
mkdir -p /etc/wg-reality
echo retained-profile > /etc/passwall2/retained-profile
echo retained-history > /etc/passwall2/monitor-history.json
echo old-backup > /etc/wg-reality/profile.json
# Exercise OpenWrt's real backup selection and restore, without flashing.
sysupgrade -b /tmp/passwall2-migration-backup.tgz
tar -tzf /tmp/passwall2-migration-backup.tgz > /tmp/passwall2-migration-backup.list
for path in etc/config/passwall2 etc/passwall2/kill-switch.nft etc/passwall2/retained-profile etc/passwall2/monitor-history.json etc/wg-reality/profile.json; do
    grep -qx "$path" /tmp/passwall2-migration-backup.list
done
uci set passwall2.test_node.uuid=must-be-restored
uci commit passwall2
rm /etc/passwall2/retained-profile
# Docker owns /etc/hosts and /etc/resolv.conf as mounts; restore only the
# application paths from the real sysupgrade archive in this container.
for path in etc/config/passwall2 etc/passwall2/kill-switch.nft etc/passwall2/retained-profile etc/passwall2/monitor-history.json etc/wg-reality/profile.json; do
    tar -xzf /tmp/passwall2-migration-backup.tgz -C / "$path"
done
test "$(uci get passwall2.test_node.uuid)" = preserved-test-value
test "$(cat /etc/passwall2/retained-profile)" = retained-profile
test "$(cat /etc/passwall2/monitor-history.json)" = retained-history
test "$(cat /etc/wg-reality/profile.json)" = old-backup
echo 'Sysupgrade backup/restore: node, guard, profiles and history retained'
touch /usr/share/nftables.d/ruleset-post/91-att-proxy.nft
nft add table inet att_proxy
sh /recipe/files/etc/uci-defaults/99-passwall2-dedicated
test "$(uci get passwall2.@global[0].kill_switch)" = 1
test "$(uci get passwall2.test_node.uuid)" = preserved-test-value
test "$(uci get passwall2.@global[0].node)" = test_node
test -f /etc/passwall2/legacy/91-att-proxy.nft.disabled
! nft list table inet att_proxy 2>/dev/null
nft list table inet passwall2_guard | grep -q '203.0.113.10'
echo 'Upgrade: node retained, new guard active, old guard retired'

# Network namespaces need a privileged disposable container, never a router.
if [ "${TEST_PACKET_LEAKS:-0}" = 1 ]; then
    sh /recipe/scripts/test-passwall2-leaks.sh
fi

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
