#
# This image uses 2 interstage and an php:7.3-apache final stage
#
# Interstages are:
#   - composer
#   - npm & yarn & grunt
#
# Final stage gets all that generated stuff and add it to the final image
#

############################
#=== composer interstage ===
############################
FROM composer:latest as composer
WORKDIR /app

#=== Get PMF source code ===
ARG PMF_BRANCH="3.0"
RUN set -x \
 && git clone \
        --depth 1 \
        -b $PMF_BRANCH \
        https://github.com/thorsten/phpMyFAQ.git \
        /app

#=== Call composer ===
RUN set -x \
  && composer install --no-dev

########################
#=== yarn interstage ===
########################
FROM node:latest as yarn
WORKDIR /app

#=== Get PMF source code from previous stage ===
COPY --from=composer /app /app

#=== Install dependencies ===
RUN set -x \
 && npm install node-sass -g --unsafe-perm

#=== Build assets ===
RUN set -x \
 && yarn install --network-timeout 1000000 \
 && yarn build

#################################
#=== Final stage with payload ===
#################################
FROM php:7.3-apache

#=== Install gd php dependencie ===
RUN set -x \
 && buildDeps="libpng-dev libjpeg-dev libfreetype6-dev" \
 && apt-get update && apt-get install -y ${buildDeps} --no-install-recommends \
 \
 && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
 && docker-php-ext-install gd \
 \
 && apt-get purge -y ${buildDeps} \
 && rm -rf /var/lib/apt/lists/*

#=== Install ldap php dependencie ===
RUN set -x \
 && buildDeps="libldap2-dev" \
 && apt-get update && apt-get install -y ${buildDeps} --no-install-recommends \
 \
 && docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/ \
 && docker-php-ext-install ldap \
 \
 && apt-get purge -y ${buildDeps} \
 && rm -rf /var/lib/apt/lists/*

#=== Install intl, opcache, and zip php dependencie ===
RUN set -x \
 && buildDeps="libicu-dev zlib1g-dev libxml2-dev" \
 && apt-get update && apt-get install -y ${buildDeps} --no-install-recommends \
 \
 && docker-php-ext-configure intl \
 && docker-php-ext-install intl \
 && docker-php-ext-install zip \
 && docker-php-ext-install opcache \
 \
 && apt-get purge -y ${buildDeps} \
 && rm -rf /var/lib/apt/lists/*

#=== Install mysqli php dependencie ===
RUN set -x \
 && docker-php-ext-install mysqli

#=== Install pgsql dependencie ===
RUN set -ex \
 && buildDeps="libpq-dev" \
 && apt-get update && apt-get install -y $buildDeps \
 \
 && docker-php-ext-configure pgsql -with-pgsql=/usr/local/pgsql \
 && docker-php-ext-install pdo pdo_pgsql pgsql \
 \
 && apt-get purge -y ${buildDeps} \
 && rm -rf /var/lib/apt/lists/*

#=== Apache vhost ===
RUN { \
  echo '<VirtualHost *:80>'; \
  echo 'DocumentRoot /var/www/html'; \
  echo; \
  echo '<Directory /var/www/html>'; \
  echo '\tOptions -Indexes'; \
  echo '\tAllowOverride all'; \
  echo '</Directory>'; \
  echo '</VirtualHost>'; \
 } | tee "$APACHE_CONFDIR/sites-available/app.conf" \
 && set -x \
 && a2ensite app \
 && a2dissite 000-default \
 && echo "ServerName localhost" >> $APACHE_CONFDIR/apache2.conf

#=== Apache security ===
RUN { \
  echo 'ServerTokens Prod'; \
  echo 'ServerSignature Off'; \
  echo 'TraceEnable Off'; \
  echo 'Header set X-Content-Type-Options: "nosniff"'; \
  echo 'Header set X-Frame-Options: "sameorigin"'; \
 } | tee $APACHE_CONFDIR/conf-available/security.conf \
 && set -x \
 && a2enconf security

#=== php default ===
ENV PMF_TIMEZONE="Europe/Berlin" \
    PMF_ENABLE_UPLOADS=On \
    PMF_MEMORY_LIMIT=64M \
    PMF_DISABLE_HTACCESS="" \
    PHP_LOG_ERRORS=On \
    PHP_ERROR_REPORTING=E_ALL\
    PHP_POST_MAX_SIZE=64M \
    PHP_UPLOAD_MAX_FILESIZE=64M

#=== Add source code from previously built interstage ===
COPY --from=yarn /app/phpmyfaq .

#=== Ensure debug mode is disabled and do some other stuff over the code ===
RUN set -x \
 && sed -ri ./src/Bootstrap.php \
      -e "s~define\('DEBUG', true\);~define\('DEBUG', false\);~" \
 && mv ./config ../saved-config

#=== Set custom entrypoint ===
COPY docker-entrypoint.sh /entrypoint
RUN chmod +x /entrypoint
ENTRYPOINT [ "/entrypoint" ]

#=== Re-Set CMD as we changed the default entrypoint ===
CMD [ "apache2-foreground" ]
