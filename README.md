## An nginx Dockerfile including the `http_auth_request_module`

This is a Dockerfile to build nginx 1.16.1 from source. I'm putting it here so I don't forget how it was done.

### Motivation

The main motivation of this work was to build nginx with the [`http_auth_request_module`](http://nginx.org/en/docs/http/ngx_http_auth_request_module.html). The common open source distributions [1] [2] of nginx do not include this module and it's needed for OAuth.

[1] https://wiki.debian.org/Nginx \
[2] http://nginx.org/en/download.html
