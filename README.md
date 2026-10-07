# squid-proxy-auth

A lightweight Squid forward-proxy Docker image with built-in basic authentication, IP allowlisting, and upstream parent proxy support — all configurable via environment variables. No need to touch `squid.conf`.

## Features

- **Tiny footprint** — based on Alpine Linux (Squid 6.x)
- **Basic auth out of the box** — credentials injected via environment variables
- **IP allowlist** — trusted source IPs bypass authentication
- **Upstream parent proxy** — chain to another proxy (e.g. a server-side relay) with one env var
- **Domain-based routing** — send specific domains directly, bypassing the parent
- **Sane defaults** — safe ports only, CONNECT restricted to SSL, headers anonymized
- **Healthcheck included** — Docker reports container health automatically
- **Persistent cache** — swap directories initialized on first run

## Quick Start (Docker Compose)

1. Clone the repo and create your `.env` file:

```bash
git clone https://github.com/behnam2/squid-proxy-auth.git
cd squid-proxy-auth
cp .env.example .env
```

2. Edit `.env` and set your credentials:

```env
PROXY_USERNAME=myuser
PROXY_PASSWORD=my-strong-password
```

3. Start the proxy:

```bash
docker compose up -d
```

4. Check that it's healthy:

```bash
docker compose ps
docker compose logs -f
```

## Quick Start (docker run)

```bash
docker run -d \
  --name squidproxy \
  -e PROXY_USERNAME=myuser \
  -e PROXY_PASSWORD=my-strong-password \
  -p 3128:3128 \
  --restart unless-stopped \
  b3hnam/squid-proxy-auth:latest
```

## Environment Variables

| Variable                  | Required | Description |
|---------------------------|----------|-------------|
| `PROXY_USERNAME`          | Yes      | Username for proxy authentication |
| `PROXY_PASSWORD`          | Yes      | Password for proxy authentication |
| `ALLOWED_IPS`             | No       | Comma-separated source IPs/CIDRs allowed **without** auth. Example: `178.22.122.200,46.102.0.0/16` |
| `DIRECT_DOMAINS`          | No       | Comma-separated domains fetched **directly**, bypassing the parent peer. Example: `ssmop.ciscoplusnet.com,.example.com` |
| `CACHE_PEER`              | No       | Upstream parent proxy: `host port [extra squid options]`. Example: `91.218.183.121 53128` |
| `CACHE_PEER_NEVER_DIRECT` | No       | Set to `1` to force **all** traffic through the parent peer |
| `PROXY_PORT`              | No       | Host port to publish (compose only, default `3128`) |
| `CONTAINER_NAME`          | No       | Container name (compose only, default `squidproxy`) |
| `CACHE_VOLUME_NAME`       | No       | Docker volume name for the cache (compose only, default `squid-cache`) |
| `COMPOSE_PROJECT_NAME`    | No       | Compose project name (default `squid-proxy-auth`) |

The container refuses to start if `PROXY_USERNAME` or `PROXY_PASSWORD` is missing.

## Usage

The proxy listens on port **3128**.

### curl

```bash
curl -x http://myuser:my-strong-password@localhost:3128 https://example.com
```

### wget

```bash
https_proxy=http://myuser:my-strong-password@localhost:3128 wget https://example.com
```

### Browser / OS

Point your browser or system proxy settings to `<host>:3128` and enter the username/password when prompted.

## Chaining to an Upstream Proxy

To forward traffic through another proxy (for example a server-side relay):

```env
CACHE_PEER=91.218.183.121 53128
```

This generates:

```
cache_peer 91.218.183.121 parent 53128 0 no-query default
cache_peer_access 91.218.183.121 allow all
```

### Force everything through the parent

```env
CACHE_PEER=91.218.183.121 53128
CACHE_PEER_NEVER_DIRECT=1
```

Adds `never_direct allow all` — Squid will never connect to origin servers directly.

### Force only allowlisted IPs through the parent

If `CACHE_PEER` is set **without** `CACHE_PEER_NEVER_DIRECT`, only `ALLOWED_IPS` clients are forced through the peer (authenticated users go direct). This matches a split-tunnel setup.

### Parent requires authentication

```env
CACHE_PEER=91.218.183.121 53128 login=parentuser:parentpass
```

## Bypassing the Parent for Specific Domains

```env
CACHE_PEER=91.218.183.121 53128
CACHE_PEER_NEVER_DIRECT=1
DIRECT_DOMAINS=ssmop.ciscoplusnet.com,.internal.example.com
```

Requests to those domains are fetched directly; everything else goes through the parent.

## Allowing Trusted IPs Without Auth

```env
ALLOWED_IPS=178.22.122.200,46.102.141.2
```

Requests from these source IPs skip authentication; everyone else must authenticate. **Note:** `localhost` is also allowed without auth by default (for health checks and local tooling).

## Verify It Works

```bash
# Without credentials — should return 407 Proxy Authentication Required
curl -x http://<server-ip>:3128 http://httpbin.org/ip

# With credentials — should return the page
curl -x http://myuser:my-strong-password@<server-ip>:3128 https://example.com
```

Check the access log to see whether traffic goes direct or via the parent:

```bash
docker logs squidproxy
# or
docker exec squidproxy tail -f /var/log/squid/access.log
```

Look for `HIER_DIRECT/<ip>` (direct) or `FIRSTUP_PARENT/<peer-ip>` (via parent).

## Security Notes

- Only "safe" ports are allowed (80, 443, and other standard ports); `CONNECT` is restricted to port 443.
- `X-Forwarded-For` headers are stripped (`forwarded_for delete`) and `Via` headers are disabled for client privacy.
- **Never commit your `.env` file** — it is gitignored by default. Use a strong password.
- Consider binding to a specific interface if you don't want the proxy exposed on all interfaces, e.g. `"127.0.0.1:3128:3128"` in the compose `ports` section.
- `ALLOWED_IPS` bypasses authentication entirely for those sources — only use it for IPs you fully trust.

## Build Locally

```bash
docker build -t squid-proxy-auth .
```

## How It Works

- `squid.conf` contains the static, hardened base config and includes `/etc/squid/conf.d/*.conf`.
- At container start, `entrypoint.sh` reads the environment variables and generates `/etc/squid/conf.d/env.conf` with the ACL, `http_access`, `cache_peer`, `cache_peer_access`, `always_direct`, and `never_direct` rules.
- Credentials are written to `/etc/squid/passwd` with `htpasswd` (bcrypt).
- The cache directory lives on a Docker volume so it survives container recreation.

If you need full control, mount your own config over `/etc/squid/squid.conf` — everything still works.

## License

MIT
