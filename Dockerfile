FROM ubuntu:22.04

LABEL maintainer="Islam Samy"

ARG WWWGROUP=1000
ARG NODE_VERSION=18
ARG POSTGRES_VERSION=15

WORKDIR /var/www/html

ENV DEBIAN_FRONTEND noninteractive
ENV TZ=UTC

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt-get update \
    && apt-get install -y gnupg gosu curl ca-certificates zip unzip git supervisor sqlite3 libcap2-bin libpng-dev python2 dnsutils \
    && curl -sS 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x14aa40ec0831756756d7f66c4f4ea0aae5267a6c' | gpg --dearmor | tee /etc/apt/keyrings/ppa_ondrej_php.gpg > /dev/null \
    && echo "deb [signed-by=/etc/apt/keyrings/ppa_ondrej_php.gpg] https://ppa.launchpadcontent.net/ondrej/php/ubuntu jammy main" > /etc/apt/sources.list.d/ppa_ondrej_php.list \
    && apt-get update \
    && apt-get install -y php8.2-cli php8.2-dev \
    php8.2-pgsql php8.2-sqlite3 php8.2-gd php8.2-imagick \
    php8.2-curl \
    php8.2-imap php8.2-mysql php8.2-mbstring \
    php8.2-xml php8.2-zip php8.2-bcmath php8.2-soap \
    php8.2-intl php8.2-readline \
    php8.2-ldap \
    php8.2-msgpack php8.2-igbinary php8.2-redis php8.2-swoole \
    php8.2-memcached php8.2-pcov php8.2-xdebug \
    && curl -sLS https://getcomposer.org/installer | php -- --install-dir=/usr/bin/ --filename=composer \
    && curl -sLS https://deb.nodesource.com/setup_$NODE_VERSION.x | bash - \
    && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | tee /etc/apt/keyrings/yarn.gpg >/dev/null \
    && echo "deb [signed-by=/etc/apt/keyrings/yarn.gpg] https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list \
    && curl -sS https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | tee /etc/apt/keyrings/pgdg.gpg >/dev/null \
    && echo "deb [signed-by=/etc/apt/keyrings/pgdg.gpg] http://apt.postgresql.org/pub/repos/apt jammy-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update \
    && apt install -y librdkafka-dev \
    && pecl install rdkafka \
    && echo "extension=rdkafka.so" > /etc/php/8.2/cli/conf.d/20-rdkafka.ini \
    && apt-get install -y mysql-client \
    && apt install -y php8.2-common \
    && apt-get install -y postgresql-client-$POSTGRES_VERSION \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* 

RUN setcap "cap_net_bind_service=+ep" /usr/bin/php8.2
RUN update-alternatives --set php /usr/bin/php8.2

# Set permissions for the web user and group
RUN groupadd --force -g $WWWGROUP sail
RUN useradd -ms /bin/bash --no-user-group -g $WWWGROUP -u 1337 sail
RUN chown -R sail:sail /var/www/html

COPY start-container.sh /usr/local/bin/start-container.sh
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY php.ini /etc/php/8.2/cli/conf.d/99-sail.ini
COPY composer.json composer.lock ./

# Switch back to root user
USER root
COPY . .

RUN chmod 777 -R /var/www/html/storage /var/www/html/public
RUN chown -R sail /var/www/html/storage /var/www/html/public
RUN chmod +x /usr/local/bin/start-container.sh

ENV PGSSLCERT /tmp/postgresql.crt

EXPOSE 8000

ENTRYPOINT ["start-container.sh"]
