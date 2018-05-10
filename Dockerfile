#
# Dockerfile that takes a base alpine image and adds
# Apache2, PHP7, composer, and drush
#
FROM alpine:latest
MAINTAINER Tom Armstrong

# Set TERM env to avoid mysql client error message "TERM environment variable not set" when running from inside the container
ENV TERM xterm

# Fix command line compile issue with bundler.
ENV LC_ALL en_US.utf8

# Custom docroot (see conf/run-httpd.sh)
ENV DOCROOT /var/www/public

RUN apk add --no-cache \ 
    bash \
    curl \
    git \
    mariadb \
    msmtp \
    net-tools \
    python3 \
    vim \ 
    wget \ 
    rsync

# NEW - Apache
RUN apk add --no-cache openrc \
    apache2 \
    apache2-ssl \
    apache2-utils \
    apache2-error \
    apache2-ctl \
    php7-apache2 \
    apache2-webdav \
    apache2-lua \
    apache2-proxy

# NEW  php
RUN apk add --no-cache 	php7 \
    php7-phar \
    php7-json \
    php7-ctype \
    php7-tokenizer \
    php7-xmlwriter \
    php7-simplexml \  
    php7-iconv \
    php7-openssl \
    php7-curl \
    php7-gd \
    php7-mysqli \
    php7-mysqlnd \
    php7-imap \
    php7-odbc \
    php7-mbstring \
    php7-mcrypt \
    php7-redis \
    php7-bcmath \
    py-setuptools

# NEW
RUN mkdir -p /usr/local/src

# # Install Composer and Drush
RUN curl -sS https://getcomposer.org/installer | php -- \
    --install-dir=/usr/local/bin \
    --filename=composer \
    --version=1.2.0 && \
    composer \
    --working-dir=/usr/local/src/ \
    global \
    require \
    drush/drush:8.* && \
    ln -s /usr/local/src/vendor/bin/drush /usr/bin/drush

RUN drush dl registry_rebuild-7.x

# NEW - Seems to be a bug
RUN mkdir /run/apache2

# Apache config, and PHP config, test apache config
# See https://github.com/docker/docker/issues/7511 /tmp usage
COPY public/index.php /var/www/public/index.php
COPY alpine /tmp/alpine/

RUN rsync -a /tmp/alpine/etc/ /etc/

RUN apachectl configtest

EXPOSE 80 443

# Simple startup script to avoid some issues observed with container restart 
ADD /run-httpd.sh /run-httpd.sh
RUN chmod -v +x /run-httpd.sh

ADD conf/mail.ini /etc/php.d/mail.ini
RUN chmod 644 /etc/php.d/mail.ini

CMD ["./run-httpd.sh"]

