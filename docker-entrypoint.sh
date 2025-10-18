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
php artisan --version || echo "Laravel test failed, but continuing..."

# Check PHP extensions
echo "Checking PHP extensions..."
for ext in pdo_mysql mbstring tokenizer xml curl openssl; do
    if ! php -m | grep -q "$ext"; then
        echo "Missing PHP extension: $ext"
        exit 1
    fi
done

# Wait for database to be ready (with timeout)
echo "Waiting for database connection..."
timeout 30 bash -c 'until php artisan migrate:status >/dev/null 2>&1; do echo "Waiting for database..."; sleep 2; done' || echo "Database not ready, continuing anyway..."

# Clear and cache Laravel configs (non-blocking)
echo "Clearing caches..."
php artisan config:clear || echo "Config clear failed, continuing..."
php artisan cache:clear || echo "Cache clear failed, continuing..."
php artisan view:clear || echo "View clear failed, continuing..."

echo "Caching config..."
php artisan config:cache || echo "Config cache failed, continuing..."

# Generate APP_KEY if missing (non-blocking)
echo "Generating app key if missing..."
php artisan key:generate --force || echo "Key generation failed, continuing..."

echo "Laravel setup complete!"

# Start supervisord to run nginx + php-fpm
echo "Starting supervisord..."
exec supervisord -c /etc/supervisor/conf.d/supervisord.conf