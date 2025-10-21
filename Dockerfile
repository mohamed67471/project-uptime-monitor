# Stage 1: Composer Build (PHP CLI)
FROM php:8.2-cli AS composer-build
WORKDIR /app

# Install system dependencies for Composer
RUN apt-get update \
 && apt-get install -y --no-install-recommends git unzip zip curl \
 && rm -rf /var/lib/apt/lists/*

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Copy PHP dependencies
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

# Stage 3: Final Image (PHP-FPM + Nginx)
FROM php:8.2-fpm-alpine
WORKDIR /var/www/html

# PHP-FPM image already has www-data user, so we use it directly

# Install dependencies and PHP extensions
RUN apk add --no-cache --virtual .build-deps $PHPIZE_DEPS \
        libpng-dev libjpeg-turbo-dev freetype-dev oniguruma-dev mariadb-connector-c-dev \
    && apk add --no-cache bash curl git tzdata nginx supervisor libpng libjpeg-turbo freetype mariadb-connector-c \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" pdo_mysql mysqli gd exif bcmath pcntl \
    && apk del .build-deps \
    && rm -rf /var/cache/apk/* /tmp/* /var/tmp/*

# Verify extensions
RUN php -m | grep -Ei 'PDO|pdo_mysql|mysqli' || { echo "PDO extensions missing!"; exit 1; }

# PHP-FPM listen configuration
RUN echo 'listen = 127.0.0.1:9001' > /usr/local/etc/php-fpm.d/zz-docker.conf

# PHP error logging
RUN { \
  echo 'error_log = /dev/stderr'; \
  echo 'log_errors = On'; \
  echo 'display_errors = Off'; \
} > /usr/local/etc/php/conf.d/docker-php-errors.ini

# Copy Nginx & Supervisor configs
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY supervisor/supervisord.conf /etc/supervisord.conf

# Copy application files
COPY . /var/www/html
COPY --from=composer-build /app/vendor /var/www/html/vendor
COPY --from=assets-build /app/public/build /var/www/html/public/build
COPY --from=composer-build /usr/local/bin/composer /usr/local/bin/composer
RUN chmod +x /usr/local/bin/composer

# Fix permissions: all files owned by www-data
RUN chown -R www-data:www-data /var/www/html \
 && find /var/www/html -type f -exec chmod 644 {} \; \
 && find /var/www/html -type d -exec chmod 755 {} \; \
 && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# Optimize Laravel
USER www-data
RUN cd /var/www/html && composer dump-autoload --optimize --no-dev
RUN php artisan config:clear || true && php artisan cache:clear || true

# Switch back to root to set Nginx directories
USER root
RUN mkdir -p /var/lib/nginx/tmp /var/log/nginx /run/nginx \
 && chown -R www-data:www-data /var/lib/nginx /var/log/nginx /run/nginx

# Configure Nginx to run as www-data
RUN sed -i 's/user  nginx;/user  www-data;/' /etc/nginx/nginx.conf

# Expose PHP-FPM port
EXPOSE 9000

# Copy entrypoint scripts
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY wait-for-db.sh /usr/local/bin/wait-for-db.sh

# Ensure scripts have LF endings and valid shebangs
RUN apk add --no-cache dos2unix \
 && sed -i '1s/^\xEF\xBB\xBF//' /usr/local/bin/docker-entrypoint.sh || true \
 && sed -i '1s/^\xEF\xBB\xBF//' /usr/local/bin/wait-for-db.sh || true \
 && dos2unix /usr/local/bin/docker-entrypoint.sh /usr/local/bin/wait-for-db.sh \
 && chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/wait-for-db.sh \
 && apk del dos2unix

# Copy supervisor config to correct path
COPY supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Run container as www-data
USER www-data

# Entrypoint & CMD
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]