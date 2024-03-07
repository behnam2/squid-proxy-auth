## squid-proxy-auth
A light Squid Proxy server with embedded basic authentication

## Deploy:

For use, you can deploy your container with this command:

```shell
docker run -d --name squidproxy -e PROXY_USERNAME=Proxy_Username -e PROXY_PASSWORD=Proxy_Password --restart unless-stopped -p 3128:3128 b3hnam/squid-proxy-auth:latest
```
