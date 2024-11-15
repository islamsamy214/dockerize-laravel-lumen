#!/usr/bin/env bash

if [ ! -z "$WWWUSER" ]; then
    usermod -u $WWWUSER app
fi

if [ ! -d /.composer ]; then
    mkdir /.composer
fi

chmod -R ugo+rw /.composer
composer install --ignore-platform-reqs --no-interaction --no-progress --working-dir=/var/www/html
php /var/www/html/artisan key:generate
php /var/www/html/artisan optimize
php /var/www/html/artisan cache:clear
php /var/www/html/artisan config:clear
php /var/www/html/artisan view:clear
php /var/www/html/artisan route:clear
php /var/www/html/artisan migrate --force
# php /var/www/html/artisan scout:sync

chown -R app:app /var/www/html
chmod -R 755 /var/www/html/storage /var/www/html/public

if [ $# -gt 0 ]; then
    exec gosu $WWWUSER "$@"
else
    exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
fi
