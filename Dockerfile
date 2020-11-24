FROM debian:buster-slim

ENV NGINX_VERSION   1.16.1
ENV NJS_VERSION     0.3.6
ENV PCRE_VERSION    8.43
ENV ZLIB_VERSION    1.2.11
ENV OPENSSL_VERSION 1.1.1c

RUN set -x \
# Create nginx user and group
    && addgroup --system --gid 101 nginx \
    && adduser --system --disabled-login --ingroup nginx --no-create-home --home /nonexistent --gecos "nginx user" --shell /bin/false --uid 101 nginx \
# Install required deb packages
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y \
    ca-certificates \
    gnupg \
    gcc \
    g++ \
    gnupg \
    libc6-dev \
    make \
    perl \
    wget \
    && rm -rf /var/cache/apt && rm -rf /var/lib/apt \
# Download the sources for nginx and dependancies
    && wget -nc https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz.asc \
                https://hg.nginx.org/njs/archive/${NJS_VERSION}.tar.gz \
                https://ftp.pcre.org/pub/pcre/pcre-${PCRE_VERSION}.tar.gz https://ftp.pcre.org/pub/pcre/pcre-${PCRE_VERSION}.tar.gz.sig \
                http://zlib.net/zlib-${ZLIB_VERSION}.tar.gz http://zlib.net/zlib-${ZLIB_VERSION}.tar.gz.asc \
                http://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz http://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz.asc -P /tmp
# Check source integrity
RUN for keyservers in \
# SKS servers
            hkps://hkps.pool.sks-keyservers.net \
            hkp://ha.pool.sks-keyservers.net \
            hkp://p80.pool.sks-keyservers.net:80 \
            hkps://pgp.mit.edu \
# Hockeypuck servers
            hkp://keyserver.ubuntu.com:80 \
# Sequoia servers
            hkps://keys.openpgp.org; \
        do gpg --keyserver-options auto-key-retrieve --keyserver ${keyservers} --verify-files /tmp/*.tar.gz.*; \
    done
RUN for file in /tmp/*.tar.gz; \
        do tar zxf "${file}" -C /usr/local/src; \
    done

# Build PCRE dependancy
WORKDIR /usr/local/src/pcre-${PCRE_VERSION}

RUN ./configure && make && make install

# Build nginx with modules and dependancies
WORKDIR /usr/local/src/nginx-${NGINX_VERSION}

RUN ./configure \
        --prefix=/etc/nginx \
        --modules-path=/usr/lib/nginx/modules \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --pid-path=/var/run/nginx.pid \
        --lock-path=/var/run/nginx.lock \
        --user=nginx \
        --group=nginx \
        --with-pcre=/usr/local/src/pcre-${PCRE_VERSION} \
        --with-pcre-jit \
        --with-zlib=/usr/local/src/zlib-${ZLIB_VERSION} \
        --with-openssl=/usr/local/src/openssl-${OPENSSL_VERSION} \
        --with-http_ssl_module \
        --with-http_v2_module \
        --with-http_realip_module \
        --with-http_auth_request_module \
        --with-http_sub_module \
        --with-stream_ssl_preread_module \
        --with-stream \
        --with-threads \
        --with-mail=dynamic \
        --add-module=/usr/local/src/njs-${NJS_VERSION}/nginx \
        --with-debug \
    && make -j$(nproc) && make install \
# cleanup deb packages and sources
    && apt-get remove --purge --auto-remove -y ca-certificates gcc g++ gnupg libc6-dev make perl wget && rm -rf /var/lib/apt/lists/* \
    && rm -rf /usr/local/src/* /tmp/* \
# forward request and error logs to docker log collector
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

EXPOSE 80 443

STOPSIGNAL SIGTERM

CMD ["nginx", "-g", "daemon off;"]
