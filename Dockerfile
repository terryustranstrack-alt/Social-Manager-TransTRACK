FROM php:8.3

# Update and install required packages
RUN apt-get update -y && apt-get install -y zip unzip git cron libzip-dev zlib1g-dev libpng-dev libjpeg-dev libfreetype6-dev clamav clamav-daemon libpq-dev nodejs npm supervisor
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer --version=2.4.4
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Configure and install PHP extensions
RUN docker-php-ext-configure mysqli \
    && docker-php-ext-install pdo pdo_mysql mysqli bcmath
RUN docker-php-ext-configure gd --with-freetype=/usr/include/ --with-jpeg=/usr/include/ \
    && docker-php-ext-install gd \
    && docker-php-ext-install zip \
    && docker-php-ext-install bcmath

# Create a user and group for the application
RUN groupadd -g 1000 www
RUN useradd -u 1000 -ms /bin/bash -g www www

# Copy application files and set working directory
COPY --chown=www:www . /var/www
WORKDIR /var/www

# Install Composer dependencies
RUN composer install --optimize-autoloader --no-dev

# Install NPM dependencies and build assets
RUN npm install

# Cache configuration and create storage link
RUN php artisan config:cache
RUN php artisan storage:link

# Set permissions for storage and cache directories
RUN chmod -R a+rw storage bootstrap/cache

# Create supervisor log directory and set permissions
RUN mkdir -p /var/log/supervisord
RUN chown -R www:www /var/log/supervisord

# Copy supervisor configuration file
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN npm run build

# Expose port
EXPOSE 9000

# Start supervisord as root
CMD ["/usr/bin/supervisord"]