#!/usr/bin/env bash

if [ ! -z "$WWWUSER" ]; then
    usermod -u $WWWUSER app
fi

if [ ! -d /.composer ]; then
    mkdir /.composer
fi

chmod -R ugo+rw /.composer
composer install --ignore-platform-reqs --no-interaction --no-progress --working-dir=/var/www/html
php artisan key:generate
php artisan cache:clear
php artisan optimize
php artisan migrate --force
# php artisan scout:sync

chown -R app:app /var/www/html
chmod -R 755 /var/www/html/storage /var/www/html/public

if [ $# -gt 0 ]; then
    exec gosu $WWWUSER "$@"
else
    exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
fi
