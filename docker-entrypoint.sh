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
        [ $tries -ge $max_tries ] && log "ERROR: $service timeout" && return 1
        sleep 2
    done
    log "$service is available"
}

log "Starting container setup..."

# Verify PHP extensions
log "Checking PHP extensions..."
REQUIRED_EXTENSIONS="pdo pdo_mysql mbstring tokenizer xml ctype json bcmath curl openssl"
for ext in $REQUIRED_EXTENSIONS; do
    check_extension "$ext" && echo "✓ $ext" || { echo "✗ $ext"; exit 1; }
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

# Test Laravel
php artisan --version || { log "ERROR: Laravel test failed"; exit 1; }
log "Laravel is ready"

# Wait for database
log "Waiting for database..."
DB_HOST_ONLY=$(echo "$DB_HOST" | cut -d: -f1)
DB_PORT_ONLY=$(echo "$DB_HOST" | cut -d: -f2)
DB_PORT_ONLY=${DB_PORT_ONLY:-3306}

wait_for_service "$DB_HOST_ONLY" "$DB_PORT_ONLY" "MySQL" || exit 1

# Test database connection
log "Testing database connection..."
DB_MAX_TRIES=30
for ((i=1; i<=DB_MAX_TRIES; i++)); do
    php artisan migrate:status >/dev/null 2>&1 && break
    [ $i -eq $DB_MAX_TRIES ] && log "ERROR: Database auth failed" && exit 1
    sleep 2
done
log "Database connected"

# Run migrations
log "Running migrations..."
php artisan migrate --force || log "WARNING: Migration failed"

# Run seeders
log "Running seeders..."
php artisan db:seed --force || log "WARNING: Seeder failed"

# Cache optimization for production
if [ "$APP_ENV" = "production" ]; then
    log "Caching for production..."
    php artisan config:cache
    php artisan route:cache
    php artisan view:cache
fi

# Generate APP_KEY if not set
[ -z "$APP_KEY" ] && log "Generating APP_KEY..." && php artisan key:generate --force

# Create storage link
[ ! -L public/storage ] && php artisan storage:link

# Create health check
[ ! -f public/health ] && echo "OK" > public/health

log "Container setup completed"
log "Starting supervisord..."

exec supervisord -c /etc/supervisor/conf.d/supervisord.conf