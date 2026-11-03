#!/bin/sh
# Run after the migration test, only in a privileged disposable OpenWrt
# container with ip-full and socat. All destinations below stay in namespaces.
set -eu
test -f /.dockerenv

cleanup() {
    for namespace in pw-client pw-uplink; do
        for pid in $(ip netns pids "$namespace" 2>/dev/null); do kill "$pid" 2>/dev/null || true; done
        ip netns delete "$namespace" 2>/dev/null || true
    done
    ip link delete pw-wan 2>/dev/null || true
    ip link delete br-lan 2>/dev/null || true
}
trap cleanup EXIT

ip netns add pw-client
ip netns add pw-uplink
ip link add br-lan type bridge
ip link add pw-lan type veth peer name pw-client0
ip link set pw-client0 netns pw-client
ip link set pw-lan master br-lan
ip link set pw-lan up
ip link set br-lan up
ip addr add 10.23.0.1/24 dev br-lan
ip link add pw-wan type veth peer name pw-uplink0
ip link set pw-uplink0 netns pw-uplink
ip addr add 198.18.0.1/30 dev pw-wan
ip link set pw-wan up
ip route add 203.0.113.0/24 via 198.18.0.2
sysctl -qw net.ipv4.ip_forward=1
sysctl -qw net.ipv6.conf.all.disable_ipv6=0
sysctl -qw net.ipv6.conf.all.forwarding=1
ip -6 addr add 2001:db8:1::1/64 dev pw-wan nodad
ip -6 addr add 2001:db8:3::1/64 dev br-lan nodad
ip -6 route add 2001:db8:2::/64 via 2001:db8:1::2

for namespace in pw-client pw-uplink; do
    ip netns exec "$namespace" ip link set lo up
    ip netns exec "$namespace" sysctl -qw net.ipv6.conf.all.disable_ipv6=0
done
ip netns exec pw-client ip link set pw-client0 up
ip netns exec pw-client ip addr add 10.23.0.2/24 dev pw-client0
ip netns exec pw-client ip route add default via 10.23.0.1
ip netns exec pw-client ip -6 addr add 2001:db8:3::2/64 dev pw-client0 nodad
ip netns exec pw-client ip -6 route add default via 2001:db8:3::1
ip netns exec pw-uplink ip link set pw-uplink0 up
ip netns exec pw-uplink ip addr add 198.18.0.2/30 dev pw-uplink0
ip netns exec pw-uplink ip addr add 203.0.113.20/32 dev lo
ip netns exec pw-uplink ip addr add 203.0.113.10/32 dev lo
ip netns exec pw-uplink ip route add 10.23.0.0/24 via 198.18.0.1
ip netns exec pw-uplink ip -6 addr add 2001:db8:1::2/64 dev pw-uplink0 nodad
ip netns exec pw-uplink ip -6 addr add 2001:db8:2::20/128 dev lo nodad
ip netns exec pw-uplink ip -6 route add 2001:db8:3::/64 via 2001:db8:1::1

ip netns exec pw-uplink socat TCP4-LISTEN:18080,reuseaddr,fork EXEC:/bin/cat &
ip netns exec pw-uplink socat TCP6-LISTEN:18080,ipv6only=1,reuseaddr,fork EXEC:/bin/cat &
ip netns exec pw-uplink socat UDP4-RECVFROM:53,bind=203.0.113.20,reuseaddr,fork EXEC:/bin/cat &
ip netns exec pw-uplink socat TCP4-LISTEN:443,reuseaddr,fork EXEC:/bin/cat &
relay_pid=$!

probe() {
    origin="$1"
    destination="$2"
    if [ "$origin" = client ]; then
        printf guard-probe | ip netns exec pw-client socat -t1 -T1 - "$destination" 2>/dev/null
    else
        printf guard-probe | socat -t1 -T1 - "$destination" 2>/dev/null
    fi
}

check_paths() {
    expected="$1"
    for origin in router client; do
        for destination in TCP4:203.0.113.20:18080,connect-timeout=1 UDP4:203.0.113.20:53 TCP6:[2001:db8:2::20]:18080,connect-timeout=1; do
            reply="$(probe "$origin" "$destination" || true)"
            if [ "$expected" = reachable ]; then
                test "$reply" = guard-probe || { echo "Baseline failed: $origin $destination" >&2; exit 1; }
            else
                test -z "$reply" || { echo "Direct traffic leaked: $origin $destination" >&2; exit 1; }
            fi
        done
    done
}

# A positive baseline proves failures below are caused by the guard rather
# than a broken topology, listener, return route, or IPv6 configuration.
fw4 stop 2>/dev/null || true
nft delete table inet passwall2_guard
check_paths reachable
echo 'Baseline: router and LAN client can reach IPv4 TCP, UDP/53 and IPv6 TCP'

sh /usr/share/passwall2/kill_switch.sh
check_paths blocked
test "$(probe router TCP4:203.0.113.10:443,connect-timeout=1)" = guard-probe
echo 'After upgrade: direct IPv4/IPv6/DNS blocked; selected relay remains reachable'

/etc/init.d/passwall2_guard stop
check_paths blocked
echo 'Proxy guard stop: direct IPv4/IPv6/DNS remain blocked'

# firewall4 includes the persisted guard in its own nft transaction. Use its
# real reload path to check that replacing fw4 cannot open a direct path.
# Leave fw4 permissive so only the independent guard can block these probes.
cat > /etc/config/firewall <<'EOF'
config defaults
    option input ACCEPT
    option output ACCEPT
    option forward ACCEPT
EOF
if ! ubus list >/dev/null 2>&1; then
    ubusd &
fi
fw4 start
fw4 reload
nft list table inet passwall2_guard | grep -q 'policy drop'
check_paths blocked
echo 'Firewall reload: direct IPv4/IPv6/DNS remain blocked'

kill "$relay_pid"
test -z "$(probe router TCP4:203.0.113.10:443,connect-timeout=1 || true)"
check_paths blocked
echo 'Relay unavailable: direct IPv4/IPv6/DNS remain blocked'

# A rejected nft transaction must retain both the live and cached old policy.
cp /usr/share/passwall2/kill_switch.lua /tmp/passwall2-renderer.before-test
cp /etc/passwall2/kill-switch.nft /tmp/passwall2-policy.before-test
printf 'io.write("invalid nft syntax\\n")\n' > /usr/share/passwall2/kill_switch.lua
if sh /usr/share/passwall2/kill_switch.sh; then
    echo 'Invalid nft transaction unexpectedly succeeded' >&2
    exit 1
fi
cmp /etc/passwall2/kill-switch.nft /tmp/passwall2-policy.before-test
check_paths blocked
cp /tmp/passwall2-renderer.before-test /usr/share/passwall2/kill_switch.lua
echo 'Rejected nft transaction: existing guard and cached policy retained'

uci set passwall2.@global[0].kill_switch_lan_devices=invalid/device
uci commit passwall2
if sh /usr/share/passwall2/kill_switch.sh; then
    echo 'Invalid guard configuration unexpectedly succeeded' >&2
    exit 1
fi
check_paths blocked
echo 'Guard render failure: emergency policy blocks direct IPv4/IPv6/DNS'
uci -q delete passwall2.@global[0].kill_switch_lan_devices
uci commit passwall2
sh /usr/share/passwall2/kill_switch.sh
