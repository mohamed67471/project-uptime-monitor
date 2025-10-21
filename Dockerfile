# Stage 1: composer build (PHP 8.2 CLI)
FROM php:8.2-cli AS composer-build
WORKDIR /app

RUN apt-get update \
 && apt-get install -y --no-install-recommends git unzip zip curl \
 && rm -rf /var/lib/apt/lists/*

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

COPY composer.json composer.lock ./
RUN composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader --classmap-authoritative --no-scripts

# Stage 2: assets build (Node.js)
FROM node:20-alpine AS assets-build
WORKDIR /app
COPY package*.json ./
COPY resources ./resources
COPY vite.config.js ./
RUN npm install && npm run build

# Stage 3: Final image with PHP-FPM + Nginx (Alpine)
FROM php:8.2-fpm-alpine

WORKDIR /var/www/html

# Create www-data user/group
RUN set -eux; \
    addgroup -g 1000 -S www-data || true; \
    adduser -u 1000 -S -G www-data www-data || true

# Install runtime libraries and build dependencies
RUN apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        libpng-dev \
        libjpeg-turbo-dev \
        freetype-dev \
        oniguruma-dev \
        mariadb-connector-c-dev \
    && apk add --no-cache \
        bash \
        curl \
        git \
        tzdata \
        nginx \
        supervisor \
        libpng \
        libjpeg-turbo \
        freetype \
    \
    # Configure GD properly
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    \
    # Install extensions
    && docker-php-ext-install -j"$(nproc)" pdo pdo_mysql mysqli gd exif bcmath pcntl \
    \
    # Cleanup build dependencies
    && apk del .build-deps \
    && rm -rf /var/cache/apk/* /tmp/* /var/tmp/*

# Verify extensions
RUN php -m | grep -E 'pdo|pdo_mysql|mysqli|gd|bcmath|pcntl'

# PHP-FPM config: listen on 127.0.0.1:9001 (so Nginx uses 9000)
RUN echo 'listen = 127.0.0.1:9001' > /usr/local/etc/php-fpm.d/zz-docker.conf

# PHP error logging to stderr
RUN echo "error_log = /dev/stderr" > /usr/local/etc/php/conf.d/docker-php-errors.ini \
 && echo "log_errors = On" >> /usr/local/etc/php/conf.d/docker-php-errors.ini \
 && echo "display_errors = On" >> /usr/local/etc/php/conf.d/docker-php-errors.ini

# Copy Nginx & Supervisor configs
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Copy app files
COPY --chown=www-data:www-data . /var/www/html

# Copy vendor and assets from previous stages
COPY --from=composer-build --chown=www-data:www-data /app/vendor /var/www/html/vendor
COPY --from=assets-build --chown=www-data:www-data /app/public/build /var/www/html/public/build

# Copy composer binary
COPY --from=composer-build /usr/local/bin/composer /usr/local/bin/composer

# Regenerate optimized autoload
RUN cd /var/www/html && composer dump-autoload --optimize --no-dev

# Clear Laravel caches
RUN php /var/www/html/artisan config:clear && php /var/www/html/artisan cache:clear

# Ensure writable directories
RUN mkdir -p /var/www/html/storage /var/www/html/bootstrap/cache \
    && chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

# Create nginx directories
RUN mkdir -p /var/lib/nginx/tmp /var/log/nginx /run/nginx \
    && chown -R www-data:www-data /var/lib/nginx /var/log/nginx /run/nginx

EXPOSE 9000

# Copy entrypoints
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY wait-for-db.sh /usr/local/bin/wait-for-db.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/wait-for-db.sh

USER root

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
