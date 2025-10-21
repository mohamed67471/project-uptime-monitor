#!/bin/sh
set -e

echo "CRITICAL: PHP Extension Verification"

# Function for consistent logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Function to check extensions using PHP itself (most reliable)
check_extension() {
    local ext="$1"
    php -r "if(extension_loaded('$ext')) exit(0); else exit(1);" >/dev/null 2>&1
}

# Function to wait for service with timeout
wait_for_service() {
    local host="$1"
    local port="$2"
    local service="$3"
    local max_tries=30
    local tries=0
    
    log "Waiting for $service at $host:$port..."
    
    while ! nc -z "$host" "$port" >/dev/null 2>&1; do
        tries=$((tries + 1))
        if [ $tries -ge $max_tries ]; then
            log "ERROR: $service connection timeout after $max_tries attempts"
            return 1
        fi
        log "Attempt $tries/$max_tries - $service not ready yet..."
        sleep 2
    done
    
    log "$service is available at $host:$port"
    return 0
}

# Show PHP version
log "PHP Version:"
php -v
echo ""

# Show configuration files being loaded
log "PHP Configuration Files:"
php --ini
echo ""

# List ALL loaded extensions with exact names for debugging
log "All Loaded PHP Extensions (exact names):"
php -m | while read line; do
    echo "  $line"
done
echo ""

# Verify PDO specifically with multiple methods
log "Verifying PDO Extensions:"

# Method 1: Using extension_loaded (most reliable)
if check_extension "pdo"; then
    echo "✓ PDO extension found (extension_loaded)"
else
    echo "✗ PDO extension NOT found (extension_loaded)"
fi

# Method 2: Using grep for visibility
if php -m | grep -i -q "^pdo$"; then
    echo "✓ PDO extension found (php -m)"
else
    echo "✗ PDO extension NOT found (php -m)"
fi

# Method 3: Using PHP code to list all PDO drivers
echo "Available PDO drivers:"
php -r "print_r(PDO::getAvailableDrivers());" 2>/dev/null || echo "PDO not available"
echo ""

# Final PDO validation
if check_extension "pdo" && php -r "class_exists('PDO') || exit(1);" 2>/dev/null; then
    echo "✓ PDO extension verified and functional"
else
    echo "✗ FATAL: PDO extension NOT functional!"
    echo ""
    echo "PHP extension directory:"
    php -i | grep "^extension_dir" | head -1
    echo ""
    echo "Contents of extension directory:"
    ls -la $(php -i | grep "^extension_dir" | cut -d' ' -f3) 2>/dev/null || echo "Cannot list extension directory"
    exit 1
fi

# Verify pdo_mysql
if check_extension "pdo_mysql"; then
    echo "✓ pdo_mysql extension found"
else
    echo "✗ FATAL: pdo_mysql extension NOT found!"
    exit 1
fi

log "Starting Laravel container setup..."

# Change to application directory
cd /var/www/html
log "Current directory: $(pwd)"

# Display directory contents for debugging
log "Directory contents:"
ls -la

log "Setting up permissions..."

# Fix permissions for Laravel
chown -R www-data:www-data storage bootstrap/cache
chmod -R 775 storage bootstrap/cache
log "Permissions set successfully"

log "Checking environment variables..."

# Check critical environment variables
echo "APP_ENV: ${APP_ENV:-not set}"
echo "APP_KEY: ${APP_KEY:0:10}... (truncated for security)"
echo "DB_CONNECTION: ${DB_CONNECTION:-not set}"
echo "DB_HOST: ${DB_HOST:-not set}"
echo "DB_PORT: ${DB_PORT:-not set}"
echo "DB_DATABASE: ${DB_DATABASE:-not set}"
echo "DB_USERNAME: ${DB_USERNAME:-not set}"

# Extract host and port from DB_HOST if it contains port
DB_HOST_ONLY="$DB_HOST"
DB_PORT_ONLY="$DB_PORT"

if echo "$DB_HOST" | grep -q ":"; then
    DB_HOST_ONLY=$(echo "$DB_HOST" | cut -d: -f1)
    DB_PORT_ONLY=$(echo "$DB_HOST" | cut -d: -f2)
fi

log "Testing Laravel installation..."
php artisan --version || {
    log "ERROR: Laravel test failed!"
    exit 1
}
log "Laravel is ready"

log "Checking PHP extensions..."

# Check required PHP extensions using reliable method
REQUIRED_EXTENSIONS="pdo pdo_mysql mbstring tokenizer xml ctype json bcmath curl openssl"
MISSING_EXTENSIONS=""

for ext in $REQUIRED_EXTENSIONS; do
    if check_extension "$ext"; then
        echo "$ext - OK"
    else
        echo "$ext - MISSING"
        MISSING_EXTENSIONS="$MISSING_EXTENSIONS $ext"
    fi
done

if [ -n "$MISSING_EXTENSIONS" ]; then
    log "ERROR: Missing required PHP extensions:$MISSING_EXTENSIONS"
    echo ""
    echo "Available extensions:"
    php -m
    echo ""
    log "Container cannot start without these extensions!"
    exit 1
fi

log "All required PHP extensions are installed"

echo ""
echo "=========================================="
log "Waiting for database connection..."
echo "=========================================="

# Wait for database connectivity first
if ! wait_for_service "$DB_HOST_ONLY" "$DB_PORT_ONLY" "MySQL"; then
    log "ERROR: Cannot connect to database at $DB_HOST_ONLY:$DB_PORT_ONLY"
    echo "Please check:"
    echo "  - DB_HOST: $DB_HOST"
    echo "  - DB_PORT: $DB_PORT"
    echo "  - DB_DATABASE: $DB_DATABASE"
    echo "  - Security groups allow ECS -> RDS connection"
    echo "  - RDS instance is running and accessible"
    exit 1
fi

# Now wait for Laravel to be able to connect with credentials
DB_MAX_TRIES=30
DB_TRIES=0

until php artisan migrate:status >/dev/null 2>&1; do
    DB_TRIES=$((DB_TRIES + 1))
    
    if [ $DB_TRIES -ge $DB_MAX_TRIES ]; then
        log "ERROR: Database authentication timeout after $DB_MAX_TRIES attempts"
        echo "Database is reachable but authentication failed."
        echo "Please check:"
        echo "  - DB_USERNAME: $DB_USERNAME"
        echo "  - DB_PASSWORD: [set]"
        echo "  - DB_DATABASE: $DB_DATABASE"
        echo "  - Database user permissions"
        exit 1
    fi
    
    log "Testing database authentication... (attempt $DB_TRIES/$DB_MAX_TRIES)"
    sleep 2
done

log "Database connection and authentication established"

echo ""
echo "=========================================="
log "Running database migrations..."
echo "=========================================="

# Run migrations with force flag for production
if php artisan migrate --force 2>&1 | tee /tmp/migration.log; then
    log "Migrations completed successfully"
else
    log "WARNING: Migration failed! Check logs above."
    echo "Database connection details:"
    echo "  DB_HOST: $DB_HOST"
    echo "  DB_DATABASE: $DB_DATABASE"
    echo "  DB_USERNAME: $DB_USERNAME"
    echo ""
    echo "Migration log:"
    cat /tmp/migration.log
    log "Continuing despite migration failure..."
fi

echo "=========================================="
log "Running database seeders..."
echo "=========================================="

# Run seeders without environment check
if php artisan db:seed --force 2>&1 | tee /tmp/seeder.log; then
    log "Seeders completed successfully"
else
    log "WARNING: Seeder failed, but continuing..."
    echo "Seeder error log:"
    cat /tmp/seeder.log
fi

# Show current migration status
echo ""
log "Current migration status:"
php artisan migrate:status

echo ""
echo "=========================================="
log "Laravel cache optimization..."
echo "=========================================="

# Clear and cache configurations
log "Clearing caches..."
php artisan config:clear || log "Config clear failed"
php artisan cache:clear || log "Cache clear failed"
php artisan view:clear || log "View clear failed"
php artisan route:clear || log "Route clear failed"

# Cache for production
if [ "$APP_ENV" = "production" ]; then
    log "Caching for production..."
    php artisan config:cache || log "Config cache failed"
    php artisan route:cache || log "Route cache failed"
    php artisan view:cache || log "View cache failed"
fi

echo ""
echo "=========================================="
log "Checking APP_KEY..."
echo "=========================================="

# Generate APP_KEY if not set
if [ -z "$APP_KEY" ]; then
    log "APP_KEY not set, generating new key..."
    php artisan key:generate --force || {
        log "ERROR: Key generation failed!"
        exit 1
    }
    log "APP_KEY generated"
else
    log "APP_KEY is set from environment"
fi

echo ""
echo "=========================================="
log "Laravel storage link..."
echo "=========================================="

# Create storage symlink if it doesn't exist
if [ ! -L public/storage ]; then
    log "Creating storage symlink..."
    php artisan storage:link || log "Storage link failed (may already exist)"
else
    log "Storage symlink already exists"
fi

echo ""
echo "=========================================="
log "Health check setup..."
echo "=========================================="

# Create a simple health check endpoint file if it doesn't exist
if [ ! -f public/health ]; then
    echo "OK" > public/health
    log "Health check endpoint created at /health"
else
    log "Health check endpoint already exists"
fi

echo ""
echo "=========================================="
log "Final system status..."
echo "=========================================="

echo "Application: $(php artisan --version)"
echo "Environment: $APP_ENV"
echo "Database: Connected to $DB_HOST/$DB_DATABASE"
echo "Cache Driver: ${CACHE_DRIVER:-not set}"
echo "Queue Driver: ${QUEUE_CONNECTION:-not set}"
echo "Session Driver: ${SESSION_DRIVER:-not set}"

# Verify critical services
log "Verifying critical services:"
check_extension "pdo" && echo "✓ PDO extension" || echo "✗ PDO extension"
check_extension "pdo_mysql" && echo "✓ MySQL PDO driver" || echo "✗ MySQL PDO driver"
php -r "try { new PDO('mysql:host=$DB_HOST_ONLY;port=$DB_PORT_ONLY', '$DB_USERNAME', '${DB_PASSWORD:-}'); echo '✓ Database connection'; } catch(Exception \$e) { echo '✗ Database connection: ' . \$e->getMessage(); }" 2>/dev/null || echo "✗ Database connection test failed"

echo ""
echo "=========================================="
log "Container setup completed successfully!"
echo "=========================================="
echo ""
log "Starting supervisord (nginx + php-fpm)..."

# Start supervisord to manage nginx and php-fpm
exec supervisord -c /etc/supervisor/conf.d/supervisord.conf