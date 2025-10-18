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

# Check environment variables (Laravel will use these instead of .env file)
echo "Checking environment variables..."
echo "APP_ENV: ${APP_ENV:-not set}"
echo "APP_KEY: ${APP_KEY:-not set}"
echo "DB_HOST: ${DB_HOST:-not set}"
echo "DB_DATABASE: ${DB_DATABASE:-not set}"

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

# Essential Laravel setup (non-blocking)
echo "Setting up Laravel..."
php artisan config:clear || echo "Config clear failed, continuing..."
php artisan view:clear || echo "View clear failed, continuing..."

# Only generate key if APP_KEY is not set
if [ -z "$APP_KEY" ]; then
    echo "APP_KEY not set, generating..."
    php artisan key:generate --force || echo "Key generation failed, continuing..."
else
    echo "APP_KEY already set from environment"
fi

echo "Laravel setup complete!"

# Start supervisord to run nginx + php-fpm
echo "Starting supervisord..."
exec supervisord -c /etc/supervisor/conf.d/supervisord.conf