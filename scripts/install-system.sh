#!/bin/sh
set -eu
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
[ "$(id -u)" = 0 ] || { echo 'Root required' >&2; exit 1; }
ROOT=$1
HOST=$2
PORT=$3
printf '%s\n' "$HOST" | awk -F. 'NF!=4 {exit 1} {for(i=1;i<=4;i++) if($i !~ /^[0-9]+$/ || $i>255) exit 1}'
case "$PORT" in ''|*[!0-9]*) exit 1 ;; esac
[ "$PORT" -ge 1 ] && [ "$PORT" -le 65535 ]
HELPER=/Library/PrivilegedHelperTools/local.proxy-bypass.sh
CONFIG=/Library/Preferences/local.proxy-bypass.conf
PLIST=/Library/LaunchDaemons/local.proxy-bypass.plist
OLD_HOST=''
if [ -r "$CONFIG" ]; then
    OLD_HOST=$(awk 'NR == 1 {print $1}' "$CONFIG")
elif [ -r "$HELPER" ]; then
    OLD_HOST=$(sed -n 's/^PROXY=\([0-9.]*\)$/\1/p' "$HELPER")
fi
plutil -lint "$ROOT/local.proxy-bypass.plist"
sh -n "$ROOT/proxy-bypass.sh"
launchctl bootout system/local.proxy-bypass 2>/dev/null || true
install -d -o root -g wheel -m 755 /Library/PrivilegedHelperTools
install -o root -g wheel -m 755 "$ROOT/proxy-bypass.sh" "$HELPER"
install -o root -g wheel -m 644 "$ROOT/local.proxy-bypass.plist" "$PLIST"
printf '%s\n%s\n' "$HOST" "$PORT" > "$CONFIG"
chown root:wheel "$CONFIG"
chmod 644 "$CONFIG"
if [ -n "$OLD_HOST" ] && [ "$OLD_HOST" != "$HOST" ]; then
    printf '%s\n' "$OLD_HOST" | awk -F. 'NF!=4 {exit 1} {for(i=1;i<=4;i++) if($i !~ /^[0-9]+$/ || $i>255) exit 1}'
    route -n delete -host "$OLD_HOST" >/dev/null 2>&1 || true
fi
rm -f /var/run/local.proxy-bypass/target /var/run/local.proxy-bypass/last-probe
launchctl bootstrap system "$PLIST"
launchctl kickstart system/local.proxy-bypass
