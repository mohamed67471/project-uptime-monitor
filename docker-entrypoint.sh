#!/bin/bash
set -e

echo "Starting container setup..."

# Ensure we are in the app directory
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
php artisan --version || echo "Laravel command failed!"

# Check PHP extensions
echo "Checking PHP extensions..."
for ext in pdo_mysql mbstring tokenizer xml curl openssl; do
    php -m | grep -q "$ext" || echo "Missing PHP extension: $ext"
done

# Clear and cache Laravel configs
echo "Clearing caches..."
php artisan config:clear || echo "Config clear failed"
php artisan cache:clear || echo "Cache clear failed"
php artisan view:clear || echo "View clear failed"

echo "Caching config..."
php artisan config:cache || echo "Config cache failed!"

# Test DB connection
echo "Testing database connection..."
php artisan migrate:status || echo "Database connection failed!"

# Generate APP_KEY if missing
echo "Generating app key if missing..."
php artisan key:generate --force || echo "Key generation failed"

echo "Laravel setup complete!"

# Start supervisord to run nginx + php-fpm
echo "Starting supervisord..."
exec supervisord -c /etc/supervisor/conf.d/supervisord.conf