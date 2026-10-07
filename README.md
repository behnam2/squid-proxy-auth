# squid-proxy-auth

A lightweight Squid forward-proxy Docker image with built-in basic authentication. Set a username and password via environment variables and you're ready to go.

## Features

- **Tiny footprint** — based on Alpine Linux
- **Basic auth out of the box** — credentials injected via environment variables
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

| Variable         | Required | Description                        |
|------------------|----------|------------------------------------|
| `PROXY_USERNAME` | Yes      | Username for proxy authentication  |
| `PROXY_PASSWORD` | Yes      | Password for proxy authentication  |

The container refuses to start if either variable is missing.

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

## Verify It Works

```bash
# Without credentials — should return 407 Proxy Authentication Required
curl -x http://localhost:3128 https://example.com

# With credentials — should return the page
curl -x http://myuser:my-strong-password@localhost:3128 https://example.com
```

## Security Notes

- Only "safe" ports are allowed (80, 443, and other standard ports); `CONNECT` is restricted to port 443.
- `X-Forwarded-For` headers are stripped (`forwarded_for delete`) and `Via` headers are disabled for client privacy.
- **Never commit your `.env` file** — it is gitignored by default. Use a strong password.
- Consider binding to a specific interface if you don't want the proxy exposed on all interfaces, e.g. `"127.0.0.1:3128:3128"` in the compose `ports` section.

## Build Locally

```bash
docker build -t squid-proxy-auth .
```

## Configuration

The Squid configuration lives in [`squid.conf`](squid.conf). It's a minimal, hardened config — tweak it to your needs (e.g. add ACLs, change the cache size, allow local networks without auth) and rebuild the image.

## License

MIT
