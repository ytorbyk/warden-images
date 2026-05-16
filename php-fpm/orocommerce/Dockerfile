ARG ENV_SOURCE_IMAGE="ghcr.io/wardenenv/php-fpm"
ARG PHP_VERSION="8.4"

FROM ${ENV_SOURCE_IMAGE}:${PHP_VERSION}
ARG PHP_EXTENSIONS="imap tidy ldap pecl-mongodb"

USER root

RUN set -eux \
    && PHP_PACKAGES= && for PKG in ${PHP_EXTENSIONS}; do \
        if [[ ${PKG} = "mcrypt" ]] && (( ${PHP_VERSION} > 71 )); then continue; fi; \
        if [[ ${PKG} = "sodium" ]] && (( ${PHP_VERSION} < 72 )); then continue; fi; \
        PHP_PACKAGES+="php-${PKG} "; \
    done \
    && dnf install -y ${PHP_PACKAGES} jpegoptim pngquant supervisor \
    && dnf clean all \
    && rm -rf /var/cache/dnf \
    && perl -pi -e 's/^(memory_limit)=.*$/$1=1G/g' /etc/php-fpm-fcgi.ini \
    && perl -pi -e 's/^(realpath_cache_size)=.*$/$1=4096K/g' /etc/php-fpm-fcgi.ini \
    && perl -pi -e 's/^(realpath_cache_ttl)=.*$/$1=600/g' /etc/php-fpm-fcgi.ini \
    && OPCACHE_INI=/etc/php.d/10-opcache.ini \
    && if [ ! -f "${OPCACHE_INI}" ]; then \
           printf '[opcache]\nzend_extension=opcache.so\nopcache.enable=0\nopcache.enable_cli=0\nopcache.memory_consumption=128\nopcache.interned_strings_buffer=8\nopcache.max_accelerated_files=10000\nopcache.save_comments=1\n' > "${OPCACHE_INI}"; \
       fi \
    && perl -pi -e 's/^;?\s*(opcache\.enable)\s*=.*$/$1=1/g' "${OPCACHE_INI}" \
    && perl -pi -e 's/^;?\s*(opcache\.enable_cli)\s*=.*$/$1=0/g' "${OPCACHE_INI}" \
    && perl -pi -e 's/^;?\s*(opcache\.memory_consumption)\s*=.*$/$1=512/g' "${OPCACHE_INI}" \
    && perl -pi -e 's/^;?\s*(opcache\.interned_strings_buffer)\s*=.*$/$1=32/g' "${OPCACHE_INI}" \
    && perl -pi -e 's/^;?\s*(opcache\.max_accelerated_files)\s*=.*$/$1=32531/g' "${OPCACHE_INI}" \
    && perl -pi -e 's/^;?\s*(opcache\.save_comments)\s*=.*$/$1=1/g' "${OPCACHE_INI}"

RUN mkdir -p /var/log/supervisor \
    && chown www-data:www-data /var/log/supervisor

COPY oro-init /usr/local/bin/
COPY etc/php.d/*.ini /etc/php.d/
COPY etc/supervisord.d/* /etc/supervisord.d/

# Disabling Phar extension
RUN sed 's/^\(extension=phar\)/;\1/' /etc/php.d/*-phar.ini

# Inject the oro customization before starting PHP-FPM
RUN sed -i '/^exec "\$@"/i oro-init\n' /usr/local/bin/docker-entrypoint

USER www-data
