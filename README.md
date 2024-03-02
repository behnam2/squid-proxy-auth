# squid-proxy-auth
A lite Squid Proxy server with embedded basic authentication

For use, you can run your container with this command:

docker run -d --name squidproxy -e PROXY_USERNAME=Proxy_Username -e PROXY_PASSWORD=Proxy_Password --restart unless-stopped -p 3128:3128 b3hnam/squid-proxy-auth:latest
