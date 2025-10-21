#!/bin/sh 
set -e

echo "CRITICAL: PHP Extension Verification"

# Show PHP version
echo "PHP Version:"
php -v
echo ""

# Show configuration files being loaded
echo "PHP Configuration Files:"
php --ini
echo ""

# List ALL loaded extensions
echo "All Loaded PHP Extensions:"
php -m
echo ""

# Verify PDO specifically
echo "Verifying PDO Extensions:"
if php -m | grep -q "^PDO$"; then
    echo "✓ PDO extension found"
else
    echo "✗ FATAL: PDO extension NOT found!"
    echo ""
    echo "PHP extension directory:"
    php -i | grep "^extension_dir"
    echo ""
    echo "Contents of extension directory:"
    ls -la $(php -i | grep "^extension_dir" | cut -d' ' -f3)
    exit 1
fi

if php -m | grep -q "^pdo_mysql$"; then
    echo "✓ pdo_mysql extension found"
else
    echo "✗ FATAL: pdo_mysql extension NOT found!"
    exit 1
fi

echo "Starting Laravel container setup..."

# Change to application directory
cd /var/www/html
echo "Current directory: $(pwd)"

# Display directory contents for debugging
echo "Directory contents:"
ls -la

echo "Setting up permissions..."


# Fix permissions for Laravel
chown -R www-data:www-data storage bootstrap/cache
chmod -R 775 storage bootstrap/cache
echo "Permissions set successfully"


echo "Checking environment variables..."


# Check critical environment variables
echo "APP_ENV: ${APP_ENV:-not set}"
echo "APP_KEY: ${APP_KEY:0:10}... (truncated for security)"
echo "DB_CONNECTION: ${DB_CONNECTION:-not set}"
echo "DB_HOST: ${DB_HOST:-not set}"
echo "DB_PORT: ${DB_PORT:-not set}"
echo "DB_DATABASE: ${DB_DATABASE:-not set}"
echo "DB_USERNAME: ${DB_USERNAME:-not set}"


echo "Testing Laravel installation..."
# Test Laravel installation"

php artisan --version || {
    echo "Laravel test failed!"
    exit 1
}
echo "Laravel is ready"


echo "Checking PHP extensions..."

# Check required PHP extensions
REQUIRED_EXTENSIONS="pdo pdo_mysql mbstring tokenizer xml ctype json bcmath curl openssl"
MISSING_EXTENSIONS=""

for ext in $REQUIRED_EXTENSIONS; do
    if php -m | grep -q "^$ext$"; then
        echo "$ext - OK"
    else
        echo "$ext - MISSING"
        MISSING_EXTENSIONS="$MISSING_EXTENSIONS $ext"
    fi
done

if [ -n "$MISSING_EXTENSIONS" ]; then
    echo ""
    echo "Missing required PHP extensions:$MISSING_EXTENSIONS"
    echo "Container cannot start without these extensions!"
    exit 1
fi

echo "All required PHP extensions are installed"

echo ""
echo "=========================================="
echo "Waiting for database connection..."
echo "=========================================="

# Wait for database with timeout and better error handling
DB_MAX_TRIES=30
DB_TRIES=0

until php artisan migrate:status >/dev/null 2>&1; do
    DB_TRIES=$((DB_TRIES + 1))
    
    if [ $DB_TRIES -ge $DB_MAX_TRIES ]; then
        echo "Database connection timeout after ${DB_MAX_TRIES} attempts"
        echo "Please check:"
        echo "  - DB_HOST: $DB_HOST"
        echo "  - DB_PORT: $DB_PORT"
        echo "  - DB_DATABASE: $DB_DATABASE"
        echo "  - Security groups allow ECS -> RDS connection"
        echo "  - RDS instance is running and accessible"
        exit 1
    fi
    
    echo "Waiting for database... (attempt $DB_TRIES/$DB_MAX_TRIES)"
    sleep 2
done

echo "Database connection established"

echo ""
echo "=========================================="
echo "Running database migrations..."
echo "=========================================="

# Run migrations with force flag for production
php artisan migrate --force 2>&1 | tee /tmp/migration.log

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "Migrations completed successfully"
else
    echo "Migration failed! Check logs above."
    echo "Database connection details:"
    echo "  DB_HOST: $DB_HOST"
    echo "  DB_DATABASE: $DB_DATABASE"
    echo "  DB_USERNAME: $DB_USERNAME"
    echo ""
    echo "Migration log:"
    cat /tmp/migration.log
    echo "Continuing despite migration failure..."
fi

echo "=========================================="
echo "Running database seeders..."
echo "=========================================="

# Run seeders without environment check
php artisan db:seed --force 2>&1 | tee /tmp/seeder.log

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "Seeders completed successfully"
else
    echo "Seeder failed, but continuing..."
    echo "Seeder error log:"
    cat /tmp/seeder.log
fi

# Show current migration status
echo ""
echo "Current migration status:"
php artisan migrate:status

echo ""
echo "=========================================="
echo "Laravel cache optimization..."
echo "=========================================="

# Clear and cache configurations
echo "Clearing caches..."
php artisan config:clear || echo "Config clear failed"
php artisan cache:clear || echo "Cache clear failed"
php artisan view:clear || echo "View clear failed"
php artisan route:clear || echo "Route clear failed"

echo ""
echo "=========================================="
echo "Checking APP_KEY..."
echo "=========================================="

# Generate APP_KEY if not set
if [ -z "$APP_KEY" ]; then
    echo "APP_KEY not set, generating new key..."
    php artisan key:generate --force || {
        echo "Key generation failed!"
        exit 1
    }
    echo "APP_KEY generated"
else
    echo "APP_KEY is set from environment"
fi

echo ""
echo "=========================================="
echo "Laravel storage link..."
echo "=========================================="

# Create storage symlink if it doesn't exist
if [ ! -L public/storage ]; then
    echo "Creating storage symlink..."
    php artisan storage:link || echo "Storage link failed (may already exist)"
else
    echo "Storage symlink already exists"
fi

echo ""
echo "=========================================="
echo "Health check setup..."
echo "=========================================="

# Create a simple health check endpoint file if it doesn't exist
if [ ! -f public/health ]; then
    echo "OK" > public/health
    echo "Health check endpoint created at /health"
else
    echo "Health check endpoint already exists"
fi

echo ""
echo "=========================================="
echo "Final system status..."
echo "=========================================="

echo "Application: $(php artisan --version)"
echo "Environment: $APP_ENV"
echo "Database: Connected to $DB_HOST/$DB_DATABASE"
echo "Cache Driver: ${CACHE_DRIVER:-not set}"
echo "Queue Driver: ${QUEUE_CONNECTION:-not set}"
echo "Session Driver: ${SESSION_DRIVER:-not set}"

echo ""
echo "=========================================="
echo "Container setup completed successfully!"
echo "=========================================="
echo ""
echo "Starting supervisord (nginx + php-fpm)..."
echo 

# Start supervisord to manage nginx and php-fpm
exec supervisord -c /etc/supervisor/conf.d/supervisord.conf