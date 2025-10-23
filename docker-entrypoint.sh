#!/bin/sh
set -e

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Check PHP extension
check_extension() {
    php -r "if(extension_loaded('$1')) exit(0); else exit(1);" >/dev/null 2>&1
}

# Wait for service
wait_for_service() {
    local host="$1" port="$2" service="$3" max_tries=30 tries=0
    
    log "Waiting for $service at $host:$port..."
    while ! nc -z "$host" "$port" >/dev/null 2>&1; do
        tries=$((tries + 1))
        if [ $tries -ge $max_tries ]; then
            log "ERROR: $service timeout"
            return 1
        fi
        sleep 2
    done
    log "$service is available"
}

log "Starting container setup..."

# Verify PHP extensions
log "Checking PHP extensions..."
REQUIRED_EXTENSIONS="pdo pdo_mysql mbstring tokenizer xml ctype json bcmath curl openssl"
for ext in $REQUIRED_EXTENSIONS; do
    if check_extension "$ext"; then
        echo "✓ $ext"
    else
        echo "✗ $ext"
        exit 1
    fi
done

# Change to app directory
cd /var/www/html
log "Current directory: $(pwd)"

# Set permissions
chown -R www-data:www-data storage bootstrap/cache
chmod -R 775 storage bootstrap/cache
log "Permissions set"

# Create .env file from environment variables
log "Creating .env file..."
cat > .env << EOF
APP_NAME="Uptime Monitor"
APP_ENV=${APP_ENV:-production}
APP_KEY=${APP_KEY}
APP_DEBUG=false
APP_URL=${APP_URL:-https://tm.mohamed-uptime.com}
APP_TIMEZONE=UTC

LOG_CHANNEL=stack
LOG_DEPRECATIONS_CHANNEL=null
LOG_LEVEL=debug

DB_CONNECTION=mysql
DB_HOST=${DB_HOST}
DB_PORT=3306
DB_DATABASE=${DB_DATABASE:-uptime}
DB_USERNAME=${DB_USERNAME:-admin}
DB_PASSWORD=${DB_PASSWORD}

BROADCAST_DRIVER=log
CACHE_DRIVER=file
FILESYSTEM_DISK=local
QUEUE_CONNECTION=sync
SESSION_DRIVER=file
SESSION_LIFETIME=120

MEMCACHED_HOST=127.0.0.1
REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379

MAIL_MAILER=smtp
MAIL_HOST=mailpit
MAIL_PORT=1025
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
MAIL_FROM_ADDRESS="hello@example.com"
MAIL_FROM_NAME="Uptime Monitor"

AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-eu-west-2}
AWS_BUCKET=
AWS_USE_PATH_STYLE_ENDPOINT=false

PUSHER_APP_ID=
PUSHER_APP_KEY=
PUSHER_APP_SECRET=
PUSHER_HOST=
PUSHER_PORT=443
PUSHER_SCHEME=https
PUSHER_APP_CLUSTER=mt1

VITE_APP_NAME="Uptime Monitor"
VITE_PUSHER_APP_KEY=
VITE_PUSHER_HOST=
VITE_PUSHER_PORT=443
VITE_PUSHER_SCHEME=https
VITE_PUSHER_APP_CLUSTER=mt1

TELEGRAM_NOTIFER_TOKEN=${TELEGRAM_NOTIFER_TOKEN:-}
EOF

log ".env file created"

# Debug database connection
log "DEBUG - Database connection details:"
echo "DB_HOST: $DB_HOST"
echo "DB_USERNAME: $DB_USERNAME"
echo "DB_DATABASE: $DB_DATABASE"
echo "DB_PASSWORD length: ${#DB_PASSWORD} characters"

# Extract host and port from DB_HOST
DB_HOST_ONLY=$(echo "$DB_HOST" | cut -d: -f1)
DB_PORT_ONLY=$(echo "$DB_HOST" | cut -d: -f2)
DB_PORT_ONLY=${DB_PORT_ONLY:-3306}

log "DEBUG - Extracted host: $DB_HOST_ONLY, port: $DB_PORT_ONLY"

# Test network connectivity first
log "Testing network connectivity to database..."
if nc -z "$DB_HOST_ONLY" "$DB_PORT_ONLY"; then
    log "✓ Network connection successful"
else
    log "✗ Network connection failed"
    exit 1
fi
\$dsn = 'mysql:host=${DB_HOST_ONLY};port=${DB_PORT_ONLY};dbname=${DB_DATABASE}';
# Test raw PHP database connection
log "Testing PHP database connection..."
php -r "

try {
    \$pdo = new PDO(\$dsn, '${DB_USERNAME}', '${DB_PASSWORD}');
    echo 'SUCCESS: Raw database connection working\n';
} catch (Exception \$e) {
    echo 'ERROR: Raw connection failed: ' . \$e->getMessage() . '\n';
    exit(1);
}
"

# Test Laravel
php artisan --version || { log "ERROR: Laravel test failed"; exit 1; }
log "Laravel is ready"

# Wait for database to be fully ready
log "Waiting for database to be ready..."
DB_HOST_ONLY=$(echo "$DB_HOST" | cut -d: -f1)
DB_PORT_ONLY=$(echo "$DB_HOST" | cut -d: -f2)
DB_PORT_ONLY=${DB_PORT_ONLY:-3306}

wait_for_service "$DB_HOST_ONLY" "$DB_PORT_ONLY" "MySQL" || exit 1

# Test Laravel database authentication
log "Testing Laravel database authentication..."
DB_MAX_TRIES=30
i=1
while [ $i -le $DB_MAX_TRIES ]; do
    if php artisan migrate:status >/dev/null 2>&1; then
        log "✓ Laravel database authentication successful"
        break
    fi
    if [ $i -eq $DB_MAX_TRIES ]; then
        log "ERROR: Laravel database auth failed after $DB_MAX_TRIES attempts"
        exit 1
    fi
    log "Database auth attempt $i/$DB_MAX_TRIES failed, retrying..."
    i=$((i + 1))
    sleep 2
done

log "Database connected and authenticated"

# Run migrations
log "Running migrations..."
php artisan migrate --force || log "WARNING: Migration failed"

# Run seeders
log "Running seeders..."
php artisan db:seed --force || log "WARNING: Seeder failed"

# Cache optimization for production
if [ "$APP_ENV" = "production" ]; then
    log "Caching for production..."
    php artisan config:cache || true
    php artisan route:cache || true
    php artisan view:cache || true
fi

# Generate APP_KEY if not set
if [ -z "$APP_KEY" ]; then
    log "Generating APP_KEY..."
    php artisan key:generate --force || exit 1
fi

# Create storage link
if [ ! -L public/storage ]; then
    php artisan storage:link || true
fi

# Create health check
if [ ! -f public/health ]; then
    echo "OK" > public/health
fi

log "Container setup completed"
log "Starting supervisord..."

exec supervisord -c /etc/supervisor/conf.d/supervisord.conf