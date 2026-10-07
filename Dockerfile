FROM alpine:3.21

RUN apk add --no-cache squid apache2-utils curl && \
    mv /etc/squid/squid.conf /etc/squid/squid.conf.default

COPY squid.conf /etc/squid/squid.conf
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 3128

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -sf -x http://127.0.0.1:3128 http://www.google.com -o /dev/null || exit 1

ENTRYPOINT ["/entrypoint.sh"]
