#!/bin/bash
set -e

echo "Starting container setup..."

cd /var/www/html
echo "Current directory: $(pwd)"
ls -la

# Fix permissions for Laravel
echo "Setting permissions..."
chown -R www-data:www-data storage bootstrap/cache
chmod -R 775 storage bootstrap/cache

# Check .env file
if [ -f .env ]; then
    echo ".env file exists"
    grep APP_KEY .env || echo "APP_KEY not set"
else
    echo ".env file missing!"
fi

# Test Laravel
echo "Testing Laravel..."
php artisan --version

# Check PHP extensions
echo "Checking PHP extensions..."
for ext in pdo_mysql mbstring tokenizer xml curl openssl; do
    if ! php -m | grep -q "$ext"; then
        echo "Missing PHP extension: $ext"
        exit 1
    fi
done

# Clear and cache Laravel configs
echo "Clearing caches..."
php artisan config:clear
php artisan cache:clear
php artisan view:clear

echo "Caching config..."
php artisan config:cache

# Test DB connection
echo "Testing database connection..."
php artisan migrate:status

# Generate APP_KEY if missing
echo "Generating app key if missing..."
php artisan key:generate --force

echo "Laravel setup complete!"

# Start supervisord to run nginx + php-fpm
echo "Starting supervisord..."
exec supervisord -c /etc/supervisor/conf.d/supervisord.conf