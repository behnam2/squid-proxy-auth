#!/bin/sh
set -e

: "${PROXY_USERNAME:?PROXY_USERNAME is required}"
: "${PROXY_PASSWORD:?PROXY_PASSWORD is required}"

htpasswd -bc /etc/squid/passwd "$PROXY_USERNAME" "$PROXY_PASSWORD"

# Generate env-driven config
mkdir -p /etc/squid/conf.d
rm -f /etc/squid/conf.d/env.conf
# Always keep at least one file so the include glob never fails
touch /etc/squid/conf.d/00-placeholder.conf

# ALLOWED_IPS: comma-separated list of source IPs/CIDRs allowed without auth
# Example: ALLOWED_IPS="1.2.3.4,5.6.7.0/24"
if [ -n "$ALLOWED_IPS" ]; then
    {
        printf 'acl allowed_ips src'
        echo "$ALLOWED_IPS" | tr ',' '\n' | sed 's/^ *//;s/ *$//' | while IFS= read -r ip; do
            [ -n "$ip" ] && printf ' %s' "$ip"
        done
        printf '\nhttp_access allow allowed_ips\n'
    } >> /etc/squid/conf.d/env.conf
    echo ">> ALLOWED_IPS: $ALLOWED_IPS"
fi

# CACHE_PEER: upstream parent proxy
# Example: CACHE_PEER="91.218.183.121 53128"
#          CACHE_PEER="91.218.183.121 53128 login=user:pass"
# CACHE_PEER_NEVER_DIRECT=1 forces all traffic through the peer
if [ -n "$CACHE_PEER" ]; then
    # shellcheck disable=SC2086
    set -- $CACHE_PEER
    PEER_HOST="$1"
    PEER_PORT="${2:-3128}"
    shift 2 2>/dev/null || shift $#
    PEER_OPTS="$*"
    {
        echo "cache_peer $PEER_HOST parent $PEER_PORT 0 no-query default $PEER_OPTS"
        echo "cache_peer_access $PEER_HOST allow all"
        if [ "$CACHE_PEER_NEVER_DIRECT" = "1" ] || [ "$CACHE_PEER_NEVER_DIRECT" = "true" ]; then
            echo "never_direct allow all"
        fi
    } >> /etc/squid/conf.d/env.conf
    echo ">> CACHE_PEER: $PEER_HOST:$PEER_PORT $PEER_OPTS (never_direct=${CACHE_PEER_NEVER_DIRECT:-off})"
fi

mkdir -p /var/spool/squid /var/log/squid
chown -R squid:squid /var/spool/squid /var/log/squid /etc/squid/conf.d

if [ ! -d /var/spool/squid/00 ]; then
    squid -z -N
fi

exec squid -N
