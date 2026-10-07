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

# ALLOWED_IPS: comma-separated source IPs/CIDRs allowed without auth.
# These clients are also forced through the cache_peer (never_direct) if one is set.
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

# DIRECT_DOMAINS: comma-separated domains that must always be fetched
# directly, bypassing the cache_peer.
# Example: DIRECT_DOMAINS="ssmop.ciscoplusnet.com,.example.com"
if [ -n "$DIRECT_DOMAINS" ]; then
    {
        printf 'acl direct_domain dstdomain'
        echo "$DIRECT_DOMAINS" | tr ',' '\n' | sed 's/^ *//;s/ *$//' | while IFS= read -r d; do
            [ -n "$d" ] && printf ' %s' "$d"
        done
        printf '\nalways_direct allow direct_domain\n'
    } >> /etc/squid/conf.d/env.conf
    echo ">> DIRECT_DOMAINS: $DIRECT_DOMAINS"
fi

# CACHE_PEER: upstream parent proxy
# Example: CACHE_PEER="91.218.183.121 53128"
#          CACHE_PEER="91.218.183.121 53128 login=user:pass"
# CACHE_PEER_NEVER_DIRECT=1 forces ALL traffic through the peer.
# If unset but ALLOWED_IPS is set, only those IPs are forced through the peer.
if [ -n "$CACHE_PEER" ]; then
    # shellcheck disable=SC2086
    set -- $CACHE_PEER
    PEER_HOST="$1"
    PEER_PORT="${2:-3128}"
    shift 2 2>/dev/null || shift $#
    PEER_OPTS="$*"
    {
        echo "cache_peer $PEER_HOST parent $PEER_PORT 0 no-query default $PEER_OPTS"
        if [ -n "$DIRECT_DOMAINS" ]; then
            echo "cache_peer_access $PEER_HOST deny direct_domain"
        fi
        echo "cache_peer_access $PEER_HOST allow all"
        if [ "$CACHE_PEER_NEVER_DIRECT" = "1" ] || [ "$CACHE_PEER_NEVER_DIRECT" = "true" ]; then
            echo "never_direct allow all"
        elif [ -n "$ALLOWED_IPS" ]; then
            echo "never_direct allow allowed_ips"
        fi
        echo "never_direct deny all"
    } >> /etc/squid/conf.d/env.conf
    echo ">> CACHE_PEER: $PEER_HOST:$PEER_PORT $PEER_OPTS (never_direct=${CACHE_PEER_NEVER_DIRECT:-allowed_ips_only})"
fi

mkdir -p /var/spool/squid /var/log/squid
chown -R squid:squid /var/spool/squid /var/log/squid /etc/squid/conf.d

if [ ! -d /var/spool/squid/00 ]; then
    squid -z -N
fi

exec squid -N
