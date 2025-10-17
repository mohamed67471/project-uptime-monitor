#!/bin/sh
set -e

echo "Starting entrypoint script..."

# Wait for database
/usr/local/bin/wait-for-db.sh

echo "Database ready! Running migrations..."
php /var/www/html/artisan migrate --force

# echo "Seeding database..."
# php /var/www/html/artisan db:seed --force --class=DefaultUserTableSeeder

echo "Starting application..."
exec "$@"

