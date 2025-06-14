ARG PHP_SOURCE_IMAGE="ghcr.io/wardenenv/centos-php"
ARG PHP_VERSION="8.4"
ARG PHP_VARIANT="fpm-loaders"

FROM ${PHP_SOURCE_IMAGE}:${PHP_VERSION}-${PHP_VARIANT}

# Clear undesired settings from base fpm images
ENV COMPOSER_ALLOW_SUPERUSER=""
ENV COMPOSER_HOME=""

ENV MAILHOG_HOST=mailhog
ENV MAILHOG_PORT=1025

ENV NODE_VERSION=20

RUN dnf install -y which pv sudo bind-utils python3-pip bash-completion rsync socat oathtool \
        wget ack make gcc gcc-c++ automake autoconf crontabs mariadb nano vim coreutils-common \
    && dnf clean all \
    && rm -rf /var/cache/dnf

RUN npm install -g n \
    && n install ${NODE_VERSION} \
    && rm -rf /usr/local/n/versions/node
RUN npm install -g npm

COPY docker-entrypoint /usr/local/bin/
COPY etc/profile.d/*.sh /etc/profile.d/
COPY etc/*.ini /etc/
COPY etc/php.d/*.ini /etc/php.d/
COPY etc/php.d/05-additions.ini.template /etc/php.d/

# Install mhsendmail to support routing email through mailhog
RUN sh < <(curl -sL https://raw.githubusercontent.com/axllent/mailpit/develop/install.sh)
RUN mv /usr/local/bin/mailpit /usr/local/bin/mhsendmail

# Install awscli to support data backfill workflows using S3 storage; segno for QR code generation
RUN pip3 install awscli segno --no-cache-dir

# Configure www-data user as primary php-fpm user for better local dev experience
RUN useradd www-data \
    && chmod 0755 ~www-data \
    && mkdir -p /var/www/html \
    && chown www-data:www-data /var/www/html \
    && echo "www-data ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd \
    && PHP_FPM_USER=$(grep -i '^user = ' /etc/php-fpm.d/www.conf | awk '{print $3}') \
    && PHP_FPM_GROUP=$(grep -i '^group = ' /etc/php-fpm.d/www.conf | awk '{print $3}') \
    && find /var/log /var/lib/php -uid $(id -u ${PHP_FPM_USER}) | xargs chown www-data \
    && find /var/log /var/lib/php -gid $(id -g ${PHP_FPM_GROUP}) | xargs chgrp www-data \
    && perl -pi -e 's/^(user|group) = php-fpm$/$1 = www-data/g' /etc/php-fpm.d/www.conf \
    && chown :www-data -R /opt

WORKDIR /var/www/html
USER www-data
