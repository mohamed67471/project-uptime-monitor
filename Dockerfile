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

# Stage 3: Final image (PHP-FPM + Nginx)
FROM php:8.2-fpm-alpine

WORKDIR /var/www/html

# Create www-data user with explicit UID/GID
RUN set -eux; \
    delgroup www-data 2>/dev/null || true; \
    deluser www-data 2>/dev/null || true; \
    addgroup -g 1000 -S www-data; \
    adduser -u 1000 -D -S -G www-data www-data

# Install runtime dependencies and PHP extensions
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
        mariadb-connector-c \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" pdo pdo_mysql mysqli gd exif bcmath pcntl \
    && apk del .build-deps \
    && rm -rf /var/cache/apk/* /tmp/* /var/tmp/*

# CRITICAL: Verify extensions are installed
RUN php -m | grep -E 'PDO|pdo_mysql|mysqli' || { \
        echo "FATAL: PDO extensions not found after installation!"; \
        php -m; \
        exit 1; \
    }

# PHP-FPM configuration
RUN echo 'listen = 127.0.0.1:9001' > /usr/local/etc/php-fpm.d/zz-docker.conf

# PHP error logging
RUN { \
        echo 'error_log = /dev/stderr'; \
        echo 'log_errors = On'; \
        echo 'display_errors = Off'; \
    } > /usr/local/etc/php/conf.d/docker-php-errors.ini

# Copy Nginx & Supervisor configs
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Copy application files with root, then fix ownership
COPY . /var/www/html

# Copy vendor and assets from build stages
COPY --from=composer-build /app/vendor /var/www/html/vendor
COPY --from=assets-build /app/public/build /var/www/html/public/build
COPY --from=composer-build /usr/local/bin/composer /usr/local/bin/composer

# Fix ALL ownership and permissions
RUN chown -R www-data:www-data /var/www/html \
    && find /var/www/html -type f -exec chmod 644 {} \; \
    && find /var/www/html -type d -exec chmod 755 {} \; \
    && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# Regenerate autoload
RUN cd /var/www/html && composer dump-autoload --optimize --no-dev

# Clear Laravel caches (with error handling)
RUN php /var/www/html/artisan config:clear || true \
    && php /var/www/html/artisan cache:clear || true

# Create nginx directories
RUN mkdir -p /var/lib/nginx/tmp /var/log/nginx /run/nginx \
    && chown -R www-data:www-data /var/lib/nginx /var/log/nginx /run/nginx
 Install dos2unix to handle line endings
RUN apk add --no-cache dos2unix

# Copy entrypoint scripts
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY wait-for-db.sh /usr/local/bin/wait-for-db.sh

# Fix line endings and set permissions
RUN dos2unix /usr/local/bin/docker-entrypoint.sh /usr/local/bin/wait-for-db.sh \
    && chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/wait-for-db.sh \
      && apk del dos2unix

EXPOSE 9000

USER root

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
