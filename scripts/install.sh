#!/bin/sh
# Run as your regular macOS user. sudo authenticates the system installation.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
[ "$(uname -s)" = Darwin ] || { echo 'macOS is required' >&2; exit 1; }
[ "$(id -u)" != 0 ] || { echo 'Run as your regular user, without sudo.' >&2; exit 1; }
. "$ROOT/config.local"
: "${PROXY_HOST:?}" "${PROXY_PORT:?}" "${PROXY_URL:?}"
printf '%s\n' "$PROXY_HOST" | awk -F. 'NF!=4 {exit 1} {for(i=1;i<=4;i++) if($i !~ /^[0-9]+$/ || $i>255) exit 1}'
case "$PROXY_PORT" in ''|*[!0-9]*) exit 1 ;; esac
[ "$PROXY_PORT" -ge 1 ] && [ "$PROXY_PORT" -le 65535 ]
case "$PROXY_URL" in
    http://*"@$PROXY_HOST:$PROXY_PORT"|http://"$PROXY_HOST:$PROXY_PORT") ;;
    *) echo 'PROXY_URL must use PROXY_HOST and PROXY_PORT (http).' >&2; exit 1 ;;
esac
USER_CONFIG="$HOME/Library/Application Support/ProxyRevoke"
mkdir -p "$USER_CONFIG"
chmod 700 "$USER_CONFIG"
install -m 600 "$ROOT/config.local" "$USER_CONFIG/config.local"
sudo /bin/sh "$ROOT/scripts/install-system.sh" "$ROOT" "$PROXY_HOST" "$PROXY_PORT"
mkdir -p "$HOME/Applications"
ditto "$ROOT/ProxyCurl.app" "$HOME/Applications/ProxyCurl.app"
echo "Installed proxy bypass for $PROXY_HOST:$PROXY_PORT"
