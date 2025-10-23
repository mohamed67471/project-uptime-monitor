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
DB_USERNAME=${DB_USERNAME:-uptime_user}
DB_PASSWORD=${DB_PASSWORD}

# ... rest of your .env content
EOF

log ".env file created"

# Test Laravel
if ! php artisan --version >/dev/null 2>&1; then
    log "ERROR: Laravel test failed"
    exit 1
fi
log "Laravel is ready"

# Wait for database
log "Waiting for database..."
DB_HOST_ONLY=$(echo "$DB_HOST" | cut -d: -f1)
DB_PORT_ONLY=$(echo "$DB_HOST" | cut -d: -f2)
DB_PORT_ONLY=${DB_PORT_ONLY:-3306}

if ! wait_for_service "$DB_HOST_ONLY" "$DB_PORT_ONLY" "MySQL"; then
    exit 1
fi

# Test database connection (POSIX-compliant)
log "Testing database connection..."
DB_MAX_TRIES=30
i=1
while [ $i -le $DB_MAX_TRIES ]; do
    if php artisan migrate:status >/dev/null 2>&1; then
        break
    fi
    if [ $i -eq $DB_MAX_TRIES ]; then
        log "ERROR: Database auth failed"
        exit 1
    fi
    log "Database auth attempt $i/$DB_MAX_TRIES failed, retrying..."
    i=$((i + 1))
    sleep 2
done
log "Database connected"

# Run migrations
log "Running migrations..."
if ! php artisan migrate --force; then
    log "WARNING: Migration failed"
fi

# Run seeders
log "Running seeders..."
if ! php artisan db:seed --force; then
    log "WARNING: Seeder failed"
fi

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