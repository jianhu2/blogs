From nginx:stable-alpine
COPY ./default.conf /etc/nginx/conf.d/
#COPY src/assets/favicon.ico /usr/share/nginx/html
COPY ./public /usr/share/nginx/html



