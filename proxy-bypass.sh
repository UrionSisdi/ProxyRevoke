#!/bin/sh
# Keep one proxy host outside the VPN using the active physical IPv4 uplink.
set -eu
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
CONFIG=/Library/Preferences/local.proxy-bypass.conf
PROXY=$(awk 'NR == 1 {print $1}' "$CONFIG")
PORT=$(awk 'NR == 2 {print $1}' "$CONFIG")
printf '%s\n' "$PROXY" | awk -F. 'NF!=4 {exit 1} {for(i=1;i<=4;i++) if($i !~ /^[0-9]+$/ || $i>255) exit 1}' || exit 1
case "$PORT" in ''|*[!0-9]*) exit 1 ;; esac
[ "$PORT" -ge 1 ] && [ "$PORT" -le 65535 ] || exit 1
STATE=/var/run/local.proxy-bypass

GLOBAL=$(printf 'show State:/Network/Global/IPv4\n' | scutil)
IFACE=$(printf '%s\n' "$GLOBAL" | awk '/PrimaryInterface :/ {print $3}')
GATEWAY=$(printf '%s\n' "$GLOBAL" | awk '/Router :/ {print $3}')
case "$IFACE" in
    en[0-9]*|bridge[0-9]*) ;;
    *)
        UPLINK=$(netstat -rn -f inet | awk '$1 == "default" && $4 ~ /^(en|bridge)[0-9]+$/ {print $4, $2; exit}')
        IFACE=$(printf '%s\n' "$UPLINK" | awk '{print $1}')
        GATEWAY=$(printf '%s\n' "$UPLINK" | awk '{print $2}')
        ;;
esac
printf '%s\n' "$IFACE" | grep -Eq '^(en|bridge)[0-9]+$' || exit 0
printf '%s\n' "$GATEWAY" | awk -F. 'NF!=4 {exit 1} {for(i=1;i<=4;i++) if($i !~ /^[0-9]+$/ || $i>255) exit 1}' || exit 0
ifconfig "$IFACE" | grep -q 'status: active' || exit 0
ADDRESS=$(ifconfig "$IFACE" | awk '$1 == "inet" {print $2; exit}')
[ -n "$ADDRESS" ] || exit 0
TARGET="$IFACE $GATEWAY $ADDRESS"
if [ "${1:-}" = '--print-target' ]; then
    printf '%s\n' "$TARGET"
    exit 0
fi
[ "$(id -u)" = 0 ] || { echo 'Must run as root' >&2; exit 1; }
mkdir -p "$STATE"
chmod 700 "$STATE"
CURRENT=$(route -n get "$PROXY" 2>/dev/null || true)
OLD=$(cat "$STATE/target" 2>/dev/null || true)
NOW=$(date +%s)
LAST=$(cat "$STATE/last-probe" 2>/dev/null || printf 0)
REPAIR=0
[ "$OLD" = "$TARGET" ] || REPAIR=1
[ "$(printf '%s\n' "$CURRENT" | awk '/destination:/ {print $2}')" = "$PROXY" ] || REPAIR=1
[ "$(printf '%s\n' "$CURRENT" | awk '/gateway:/ {print $2}')" = "$GATEWAY" ] || REPAIR=1
[ "$(printf '%s\n' "$CURRENT" | awk '/interface:/ {print $2}')" = "$IFACE" ] || REPAIR=1
# Probe once per minute to recover stale routes even when the gateway is unchanged.
if [ "$REPAIR" = 0 ] && [ "$((NOW - LAST))" -ge 60 ]; then
    printf '%s\n' "$NOW" > "$STATE/last-probe"
    nc -z -G 4 -w 4 "$PROXY" "$PORT" >/dev/null 2>&1 || REPAIR=1
fi
if [ "$REPAIR" = 1 ]; then
    route -n delete -host "$PROXY" >/dev/null 2>&1 || true
    route -n add -host "$PROXY" "$GATEWAY" >/dev/null
    printf '%s\n' "$TARGET" > "$STATE/target"
    printf '%s\n' "$NOW" > "$STATE/last-probe"
    logger -t local.proxy-bypass "Proxy $PROXY routed via $GATEWAY on $IFACE"
fi
