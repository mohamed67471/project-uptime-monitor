# Stage 1: composer build (PHP 8.2 CLI)
FROM php:8.2-cli AS composer-build
WORKDIR /app

# Install minimal system tools for Composer
RUN apt-get update \
 && apt-get install -y --no-install-recommends git unzip zip curl \
 && rm -rf /var/lib/apt/lists/*

# Install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Copy composer files
COPY composer.json composer.lock ./

# Install dependencies without running scripts
RUN composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader --classmap-authoritative --no-scripts

# Stage 2: Final image with Nginx + PHP-FPM (Alpine)
FROM php:8.2-fpm-alpine

WORKDIR /var/www/html

# Create www-data user/group
RUN set -eux; \
    if ! getent group www-data >/dev/null 2>&1; then addgroup -g 1000 -S www-data; fi; \
    if ! id -u www-data >/dev/null 2>&1; then adduser -u 1000 -S -G www-data www-data; fi

# Install PHP extensions, runtime deps, Nginx, and Supervisor
RUN set -eux; \
    apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS gcc g++ make autoconf musl-dev re2c pkgconf; \
    apk add --no-cache \
        libpng-dev libjpeg-turbo-dev freetype-dev oniguruma-dev mariadb-dev mysql-client \
        tzdata bash curl git \
        nginx supervisor; \
    docker-php-ext-configure gd --with-freetype --with-jpeg; \
    docker-php-ext-install -j"$(nproc)" pdo pdo_mysql mysqli gd exif bcmath pcntl; \
    apk del .build-deps; \
    rm -rf /var/cache/apk/* /tmp/* /var/tmp/*

# PHP-FPM to listen on localhost:9001 (so Nginx can use port 9000)
RUN echo 'listen = 127.0.0.1:9001' > /usr/local/etc/php-fpm.d/zz-docker.conf

# Copy Nginx config
COPY nginx/nginx.conf /etc/nginx/nginx.conf

# Copy Supervisor config
COPY supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Copy application files FIRST
COPY --chown=www-data:www-data . /var/www/html

# Copy vendor from composer stage
COPY --from=composer-build --chown=www-data:www-data /app/vendor /var/www/html/vendor

# IMPORTANT: Regenerate composer autoload with app files present
RUN cd /var/www/html && \
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
    composer dump-autoload --optimize --no-dev && \
    rm /usr/local/bin/composer

# Clear Laravel caches (as root, before USER www-data)
RUN php /var/www/html/artisan config:clear || true && \
    php /var/www/html/artisan cache:clear || true
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY wait-for-db.sh /usr/local/bin/wait-for-db.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/wait-for-db.sh


# Ensure writable dirs for Laravel
RUN mkdir -p /var/www/html/storage /var/www/html/bootstrap/cache \
    && chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

# Create nginx directories and set permissions
RUN mkdir -p /var/lib/nginx/tmp /var/log/nginx /run/nginx \
    && chown -R www-data:www-data /var/lib/nginx /var/log/nginx /run/nginx

EXPOSE 9000

# Run as root so supervisor can manage both nginx and php-fpm
USER root

# Use entrypoint to run migrations, then start supervisor
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
