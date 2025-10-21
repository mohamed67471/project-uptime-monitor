# Stage 1: Composer Build (PHP CLI)
FROM php:8.2-cli AS composer-build
WORKDIR /app

# Install system dependencies for Composer
RUN apt-get update \
 && apt-get install -y --no-install-recommends git unzip zip curl \
 && rm -rf /var/lib/apt/lists/*

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Copy PHP dependencies and install
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader --no-scripts

# Stage 2: Assets Build (Node.js)
FROM node:20-alpine AS assets-build
WORKDIR /app

# Copy package files and resources
COPY package*.json ./
COPY resources ./resources
COPY vite.config.js ./

# Install Node dependencies and build assets
RUN npm install && npm run build

# Stage 3: Final image (PHP 8.1 FPM + Nginx)
FROM php:8.1-fpm-alpine
WORKDIR /var/www/html

# Create www-data user
RUN set -eux; \
    delgroup www-data 2>/dev/null || true; \
    deluser www-data 2>/dev/null || true; \
    addgroup -g 1000 -S www-data; \
    adduser -u 1000 -D -S -G www-data www-data

# Install dependencies and PHP extensions
RUN apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        libpng-dev libjpeg-turbo-dev freetype-dev oniguruma-dev \
    && apk add --no-cache \
        bash curl git tzdata nginx supervisor libpng libjpeg-turbo freetype oniguruma \
        mariadb-connector-c mysql-client netcat-openbsd \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" pdo pdo_mysql mysqli gd exif bcmath pcntl opcache \
    && pecl install redis && docker-php-ext-enable redis \
    && apk del .build-deps \
    && rm -rf /var/cache/apk/* /tmp/* /var/tmp/*

# Verify PDO extensions are properly loaded
RUN php -r "if (!extension_loaded('pdo')) { echo 'PDO extension missing!'; exit(1); }" \
 && php -r "if (!extension_loaded('pdo_mysql')) { echo 'PDO MySQL extension missing!'; exit(1); }" \
 && echo "✓ PDO extensions verified"

# PHP-FPM configuration
RUN echo 'listen = 127.0.0.1:9001' > /usr/local/etc/php-fpm.d/zz-docker.conf

# PHP configuration
RUN { \
  echo 'error_log = /dev/stderr'; \
  echo 'log_errors = On'; \
  echo 'display_errors = Off'; \
  echo 'memory_limit = 256M'; \
  echo 'upload_max_filesize = 64M'; \
  echo 'post_max_size = 64M'; \
  echo 'max_execution_time = 300'; \
} > /usr/local/etc/php/conf.d/custom.ini

# Copy Nginx & Supervisor configs
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Copy app files
COPY . /var/www/html
COPY --from=composer-build /app/vendor /var/www/html/vendor
COPY --from=assets-build /app/public/build /var/www/html/public/build
COPY --from=composer-build /usr/local/bin/composer /usr/local/bin/composer
RUN chmod +x /usr/local/bin/composer

# Fix permissions
RUN chown -R www-data:www-data /var/www/html \
 && find /var/www/html -type f -exec chmod 644 {} \; \
 && find /var/www/html -type d -exec chmod 755 {} \; \
 && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache \
 && chmod +x /var/www/html/artisan

# Create necessary Laravel directories
RUN mkdir -p /var/www/html/storage/framework/views \
    /var/www/html/storage/framework/cache \
    /var/www/html/storage/framework/sessions \
    /var/www/html/storage/logs

# Optimize Laravel (run as www-data to avoid permission issues)
USER www-data
RUN cd /var/www/html && composer dump-autoload --optimize --no-dev
RUN php artisan config:clear || true \
 && php artisan cache:clear || true \
 && php artisan view:clear || true

USER root

# Create nginx directories
RUN mkdir -p /var/lib/nginx/tmp /var/log/nginx /run/nginx \
 && chown -R www-data:www-data /var/lib/nginx /var/log/nginx /run/nginx

EXPOSE 9000

# Copy entrypoint scripts
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY wait-for-db.sh /usr/local/bin/wait-for-db.sh

# Ensure scripts have no BOM, convert CRLF -> LF, make executable
RUN apk add --no-cache dos2unix \
 && sed -i '1s/^\xEF\xBB\xBF//' /usr/local/bin/docker-entrypoint.sh || true \
 && sed -i '1s/^\xEF\xBB\xBF//' /usr/local/bin/wait-for-db.sh || true \
 && dos2unix /usr/local/bin/docker-entrypoint.sh /usr/local/bin/wait-for-db.sh \
 && chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/wait-for-db.sh \
 && apk del dos2unix

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD php /var/www/html/artisan inspire > /dev/null 2>&1 || exit 1

USER www-data

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]