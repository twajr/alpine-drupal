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
RUN apk add --no-cache openrc
RUN apk add --no-cache apache2
RUN apk add --no-cache apache2-ssl
RUN apk add --no-cache apache2-utils
RUN apk add --no-cache apache2-error
RUN apk add --no-cache apache2-ctl
RUN apk add --no-cache php7-apache2 

# NEW  php
RUN apk add --no-cache 	php7
RUN apk add --no-cache  php7-phar 
RUN apk add --no-cache  php7-json
RUN apk add --no-cache php7-ctype

RUN apk add --no-cache php7-tokenizer
RUN apk add --no-cache  php7-xmlwriter
RUN apk add --no-cache  php7-simplexml

RUN apk add --no-cache php7-iconv 
RUN apk add --no-cache php7-openssl

RUN apk add --no-cache 	php7-curl 
RUN apk add --no-cache 	php7-gd 

RUN apk add --no-cache 	php7-mysqli
RUN apk add --no-cache 	php7-mysqlnd

RUN apk add --no-cache  php7-imap 
RUN apk add --no-cache  php7-odbc 

RUN apk add --no-cache 	php7-mbstring 
RUN apk add --no-cache 	php7-mcrypt 
RUN apk add --no-cache 	php7-redis 
RUN apk add --no-cache 	php7-bcmath 

RUN apk add --no-cache py-setuptools

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

#RUN rc-update add apache2 default

# Disable services management by systemd.
# RUN systemctl disable httpd.service

# Apache config, and PHP config, test apache config
# See https://github.com/docker/docker/issues/7511 /tmp usage
COPY public/index.php /var/www/public/index.php
COPY centos-7 /tmp/centos-7/

RUN rsync -a /tmp/centos-7/etc/ /etc/ && \
    apachectl configtest

EXPOSE 80 443

# # Simple startup script to avoid some issues observed with container restart 
ADD conf/run-httpd.sh /run-httpd.sh
RUN chmod -v +x /run-httpd.sh

ADD conf/mail.ini /etc/php.d/mail.ini
RUN chmod 644 /etc/php.d/mail.ini

CMD ["/run-httpd.sh"]

