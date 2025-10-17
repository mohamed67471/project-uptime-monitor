set -e

echo "Starting entrypoint script..."

# Wait for database
/usr/local/bin/wait-for-db.sh

echo "Database ready! Running migrations..."
php /var/www/html/artisan migrate --force

# Only seed if database is empty
USER_COUNT=$(php /var/www/html/artisan tinker --execute="echo \App\Models\User::count();")
if [ "$USER_COUNT" -eq "0" ]; then
  echo "Database is empty, seeding..."
  php /var/www/html/artisan db:seed --force --class=DefaultUserTableSeeder
else
  echo "Database already has $USER_COUNT users, skipping seeding"
fi

echo "Starting application..."
exec "$@"
