FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
COPY impressum.html /usr/share/nginx/html/impressum.html
COPY datenschutz.html /usr/share/nginx/html/datenschutz.html
COPY analytics-opt-out.js /usr/share/nginx/html/analytics-opt-out.js
COPY favicon.svg /usr/share/nginx/html/favicon.svg
COPY assets/ /usr/share/nginx/html/assets/
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
