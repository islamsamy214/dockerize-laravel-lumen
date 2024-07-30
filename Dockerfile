FROM ubuntu:22.04

# Arguments
ARG WWWGROUP=1000
ARG NODE_VERSION=20
ARG POSTGRES_VERSION=16

# Work directory
WORKDIR /var/www/html

# Environment variables
ENV DEBIAN_FRONTEND noninteractive
ENV TZ=UTC
ENV SUPERVISOR_PHP_COMMAND="/usr/bin/php -d variables_order=EGPCS /var/www/html/artisan serve --host=0.0.0.0 --port=80"
# ENV SUPERVISOR_PHP_COMMAND="/usr/bin/php -d variables_order=EGPCS /var/www/html/artisan octane:start --server=swoole --host=0.0.0.0 --port=80"
ENV PGSSLCERT /tmp/postgresql.crt

# Define the timezone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Install dependencies
RUN apt-get update \
    && mkdir -p /etc/apt/keyrings \
    && apt-get install -y gnupg gosu curl ca-certificates zip unzip git supervisor \
    libcap2-bin libpng-dev python2 dnsutils librsvg2-bin fswatch \
    sqlite3 \
    librdkafka-dev \
    libuv1-dev \
    && curl -sS 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x14aa40ec0831756756d7f66c4f4ea0aae5267a6c' | gpg --dearmor | tee /etc/apt/keyrings/ppa_ondrej_php.gpg > /dev/null \
    && echo "deb [signed-by=/etc/apt/keyrings/ppa_ondrej_php.gpg] https://ppa.launchpadcontent.net/ondrej/php/ubuntu jammy main" > /etc/apt/sources.list.d/ppa_ondrej_php.list \
    && curl -sS https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | tee /etc/apt/keyrings/pgdg.gpg >/dev/null \
    && echo "deb [signed-by=/etc/apt/keyrings/pgdg.gpg] http://apt.postgresql.org/pub/repos/apt jammy-pgdg main" > /etc/apt/sources.list.d/pgdg.list 

# Install cli tools
RUN apt-get update \
    && apt-get install -y pkg-config \
    mysql-client \
    postgresql-client-$POSTGRES_VERSION

# Install PHP and PHP extensions
RUN apt-get update \
    && apt-get install -y php8.3-cli php8.3-dev \
    php8.3-curl php8.3-imap php8.3-gd php8.3-imagick \
    php8.3-mbstring php8.3-zip php8.3-bcmath \
    php8.3-intl php8.3-readline php8.3-ldap \
    php8.3-msgpack php8.3-igbinary php8.3-pcov \
    php8.3-oauth php8.3-uuid \
    php8.3-memcached \ 
    php8.3-redis \ 
    php8.3-xml php8.3-soap \
    php8.3-pgsql \
    php8.3-sqlite3 \
    php8.3-mysql \
    php8.3-mongodb \
    php8.3-swoole \
    php8.3-rdkafka \
    php8.3-protobuf php8.3-grpc \
    php8.3-xdebug 

# Install PHP extensions
RUN apt-get update \
    && pecl install channel://pecl.php.net/uv-0.3.0 \
    && echo "extension=uv.so" > /etc/php/8.3/cli/conf.d/20-uv.ini 

# Install Composer
RUN curl -sLS https://getcomposer.org/installer | php -- --install-dir=/usr/bin/ --filename=composer 

# Install Node.js
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_VERSION.x nodistro main" > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs \
    && npm install -g npm \
    && npm install -g pnpm \
    && npm install -g bun \
    && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | tee /etc/apt/keyrings/yarn.gpg >/dev/null \
    && echo "deb [signed-by=/etc/apt/keyrings/yarn.gpg] https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list \
    && apt-get update \
    && apt-get install -y yarn

# Clean up
RUN apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Set up the application
RUN setcap "cap_net_bind_service=+ep" /usr/bin/php8.3

RUN sysctl vm.overcommit_memory=1

# Add a non-root user to prevent files being created with root permissions on host machine.
RUN groupadd --force -g $WWWGROUP app
RUN useradd -ms /bin/bash --no-user-group -g $WWWGROUP -u 1337 -G sudo app

# Copy the application files
COPY start-container.sh /usr/local/bin/start-container.sh
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY php.ini /etc/php/8.3/cli/conf.d/99-app.ini
COPY . .

# Set the correct permissions on the application files
RUN chown -R app /var/www/html/storage /var/www/html/public
RUN chmod +x /usr/local/bin/start-container.sh
RUN chown -R app:app /var/www/html

# Expose the port
EXPOSE 8000

ENTRYPOINT ["start-container.sh"]
