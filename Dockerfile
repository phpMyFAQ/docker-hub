#
# This image uses 2 interstage and an php:7.1-apache final stage
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

COPY --from=composer /app /app

RUN set -x \
 && npm install node-sass -g --unsafe-perm

RUN set -x \
 && yarn install \
 && yarn build

#################################
#=== Final stage with payload ===
#################################
FROM php:7.1-apache

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

#=== Install intl, soap opcache, and zip php dependencie ===
RUN set -x \
 && buildDeps="libicu-dev zlib1g-dev libxml2-dev" \
 && apt-get update && apt-get install -y ${buildDeps} --no-install-recommends \
 \
 && docker-php-ext-configure intl \
 && docker-php-ext-install intl \
 && docker-php-ext-install zip \
 && docker-php-ext-install soap \
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

#=== php default ===
ENV PMF_TIMEZONE="Europe/Berlin" \
    PMF_ENABLE_UPLOADS=On \
    PMF_MEMORY_LIMIT=64M \
    PMF_DISABLE_HTACCESS="" \
    PHP_LOG_ERRORS=On \
    PHP_ERROR_REPORTING=E_ALL

#=== Add source code from previously built interstage ===
COPY --from=yarn /app/phpmyfaq .

#=== Ensure debug mode is disabled ===
RUN set -x \
 && sed -ri ./src/Bootstrap.php \
      -e "s~define\('DEBUG', true\);~define\('DEBUG', false\);~"

#=== Set custom entrypoint ===
COPY docker-entrypoint.sh /entrypoint
RUN chmod +x /entrypoint
ENTRYPOINT [ "/entrypoint" ]

#=== Re-Set CMD as we changed the default entrypoint ===
CMD [ "apache2-foreground" ]