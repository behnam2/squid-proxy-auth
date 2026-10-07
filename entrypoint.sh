#!/bin/sh
set -e

: "${PROXY_USERNAME:?PROXY_USERNAME is required}"
: "${PROXY_PASSWORD:?PROXY_PASSWORD is required}"

htpasswd -bc /etc/squid/passwd "$PROXY_USERNAME" "$PROXY_PASSWORD"

mkdir -p /var/spool/squid /var/log/squid
chown -R squid:squid /var/spool/squid /var/log/squid

if [ ! -d /var/spool/squid/00 ]; then
    squid -z -N
fi

exec squid -N
