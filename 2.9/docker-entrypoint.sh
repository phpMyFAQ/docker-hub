#! /bin/sh

# Exit on error
set -e

#=== Set folder permissions ===
folders="attachments data images config"

mkdir -vp $folders

{
  if [ -f "$APACHE_ENVVARS" ]; then
    . "$APACHE_ENVVARS"
    chown -R "$APACHE_RUN_USER:$APACHE_RUN_GROUP" $folders
  else
    chown -R www-data:www-data $folders
  fi
  chmod 775 $folders
}

#=== Check config files ===
if [ ! -e "./config" ]; then
  echo >&2 'WARN: missing config folder'
  echo >&2 '  Did you forget to -v some_config_folder:/var/www/html/config ?'
else
  for _file in ../saved-config/*.php; do
    [ ! -e ./config/$( basename $_file ) ] && cp -v $_file ./config/$( basename $_file )
  done
fi

if [ -f "$APACHE_ENVVARS" ]; then
  #=== Enable htaccess for search engine optimisations ===
  if [ "x${DISABLE_HTACCESS}" = "x" ]; then
      a2enmod rewrite headers
      [ ! -f /.htaccess ] && cp _.htaccess .htaccess
      sed -ri .htaccess \
        -e "s~RewriteBase /phpmyfaq/~RewriteBase /~"
      # Enabling permissions override
      sed -ri ${APACHE_CONFDIR}/sites-available/*.conf \
        -e "s~(.*AllowOverride).*~\1 All~"
  else
      rm .htaccess
      # Disabling permissions override
      sed -ri ${APACHE_CONFDIR}/sites-available/*.conf \
        -e "s~(.*AllowOverride).*~\1 none~"
  fi
fi

#=== Configure php ===
{
  echo "# php settings:"
  echo "register_globals = Off"
  echo "safe_mode = Off"
  echo "log_errors = $PHP_LOG_ERRORS"
  echo "error_reporting = $PHP_ERROR_REPORTING"
  echo "date.timezone = $PMF_TIMEZONE"
  echo "memory_limit = $PMF_MEMORY_LIMIT"
  echo "file_upload = $PMF_ENABLE_UPLOADS"
} | tee $PHP_INI_DIR/conf.d/php.ini

#=== Set recommanded opcache settings ===
# see https://secure.php.net/manual/en/opcache.installation.php
{
  echo "opcache.memory_consumption=128"
  echo "opcache.interned_strings_buffer=8"
  echo "opcache.max_accelerated_files=4000"
  echo "opcache.revalidate_freq=2"
  echo "opcache.fast_shutdown=1"
  echo "opcache.enable_cli=1"
} | tee $PHP_INI_DIR/conf.d/opcache-recommended.ini

docker-php-entrypoint "$@"
