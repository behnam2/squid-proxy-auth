FROM alpine:3.21

RUN apk add --no-cache squid apache2-utils curl && \
    mv /etc/squid/squid.conf /etc/squid/squid.conf.default

COPY squid.conf /etc/squid/squid.conf
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 3128

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD [ "$(netstat -tln 2>/dev/null | grep -c ':3128 ')" -gt 0 ] || exit 1

ENTRYPOINT ["/entrypoint.sh"]
