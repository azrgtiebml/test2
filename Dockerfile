FROM centos:latest

ENV NGINX_VERSION 1.12.1
ENV PHP_VERSION 7.1.7
#ENV DOKUWIKI_VERSION 2017-02-19b
ENV DOKUWIKI_VERSION 4f8e7d4306b067959271cb17b43f2949
#ENV DOKUWIKI_CSUM ea11e4046319710a2bc6fdf58b5cda86
ENV DOKUWIKI_CSUM 1062C8C4A23CF4986307984FFECE0F5C

RUN set -x && \
    yum install -y gcc \
    gcc-c++ \
    autoconf \
    automake \
    libtool \
    make \
    cmake \
    mc

#Install PHP library
## libmcrypt-devel DIY

RUN rpm -ivh http://dl.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm && \
    yum install -y zlib \
    zlib-devel \
    openssl \
    openssl-devel \
    pcre-devel \
    libxml2 \
    libxml2-devel \
    libcurl \
    libcurl-devel \
    libpng-devel \
    libjpeg-devel \
    freetype-devel \
    libmcrypt-devel \
    openssh-server \
    python-setuptools

#Add user
RUN mkdir -p /data/{www,phpext} && \
    useradd -r -s /sbin/nologin -d /data/www -m -k no www  && \
    echo "================================================================================" && \
    echo "                           Download nginx & php                                 " && \
    echo "================================================================================"

#Download nginx & php
RUN mkdir -p /home/nginx-php && cd $_ && \
    curl -Lk http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz | gunzip | tar x -C /home/nginx-php && \
    curl -Lk http://php.net/distributions/php-$PHP_VERSION.tar.gz | gunzip | tar x -C /home/nginx-php && \
    echo "================================================================================" && \
    echo "                             Make install nginx                                 " && \
    echo "================================================================================"

#Make install nginx
RUN cd /home/nginx-php/nginx-$NGINX_VERSION && \
    ./configure --prefix=/usr/local/nginx \
    --user=www --group=www \
    --error-log-path=/var/log/nginx_error.log \
    --http-log-path=/var/log/nginx_access.log \
    --pid-path=/var/run/nginx.pid \
    --with-pcre \
    --with-http_ssl_module \
    --without-mail_pop3_module \
    --without-mail_imap_module \
    --with-http_gzip_static_module && \
    make && make install && \
    echo "================================================================================" && \
    echo "                             Make install php                                   " && \
    echo "================================================================================"

#Make install php
RUN cd /home/nginx-php/php-$PHP_VERSION && \
    ./configure --prefix=/usr/local/php \
    --with-config-file-path=/usr/local/php/etc \
    --with-config-file-scan-dir=/usr/local/php/etc/php.d \
    --with-fpm-user=www \
    --with-fpm-group=www \
    --with-mcrypt=/usr/include \
    --with-mysqli \
    --with-pdo-mysql \
    --with-openssl \
    --with-gd \
    --with-iconv \
    --with-zlib \
    --with-gettext \
    --with-curl \
    --with-png-dir \
    --with-jpeg-dir \
    --with-freetype-dir \
    --with-xmlrpc \
    --with-mhash \
    --enable-fpm \
    --enable-xml \
    --enable-shmop \
    --enable-sysvsem \
    --enable-inline-optimization \
    --enable-mbregex \
    --enable-mbstring \
    --enable-ftp \
    --enable-gd-native-ttf \
    --enable-mysqlnd \
    --enable-pcntl \
    --enable-sockets \
    --enable-zip \
    --enable-soap \
    --enable-session \
    --enable-opcache \
    --enable-bcmath \
    --enable-exif \
    --enable-fileinfo \
    --disable-rpath \
    --enable-ipv6 \
    --disable-debug \
    --without-pear && \
    make && make install && \
    echo "================================================================================" && \
    echo "                           Make install php-fpm                                 " && \
    echo "================================================================================"

#Install php-fpm
RUN cd /home/nginx-php/php-$PHP_VERSION && \
    cp php.ini-production /usr/local/php/etc/php.ini && \
    cp /usr/local/php/etc/php-fpm.conf.default /usr/local/php/etc/php-fpm.conf && \
    cp /usr/local/php/etc/php-fpm.d/www.conf.default /usr/local/php/etc/php-fpm.d/www.conf && \
    echo "================================================================================" && \
    echo "                           Install supervisor                                   " && \
    echo "================================================================================"

#Install supervisor
RUN easy_install supervisor && \
    mkdir -p /var/{log/supervisor,run/{sshd,supervisord}} && \
    echo "================================================================================" && \
    echo "                                 Clean OS                                       " && \
    echo "================================================================================"


#Clean OS
RUN yum remove -y gcc \
    gcc-c++ \
    autoconf \
    automake \
    libtool \
    make \
    cmake && \
    yum clean all && \
    rm -rf /tmp/* /var/cache/{yum,ldconfig} /etc/my.cnf{,.d} && \
    mkdir -p --mode=0755 /var/cache/{yum,ldconfig} && \
    find /var/log -type f -delete && \
    rm -rf /home/nginx-php

ADD dokuwiki-4f8e7d4306b067959271cb17b43f2949.tgz /data/www/

RUN cd /data/www && \
    # curl -O -L "https://download.dokuwiki.org/src/dokuwiki/dokuwiki-$DOKUWIKI_VERSION.tgz" && \
    # tar -xzf "dokuwiki-$DOKUWIKI_VERSION.tgz" --strip 1 && \
    tar -xzf "dokuwiki-4f8e7d4306b067959271cb17b43f2949.tgz" --strip 1 && \
    rm "dokuwiki-$DOKUWIKI_VERSION.tgz" && \

#Change Mod from webdir
    chown -R www:www /data/www

#Add supervisord conf
ADD supervisord.conf /etc/

#Create web folder
VOLUME ["/data/www", "/usr/local/nginx/conf/ssl", "/usr/local/nginx/conf/vhost", "/usr/local/php/etc/php.d", "/data/phpext"]

#ADD index.php /data/www/

ADD extini/ /usr/local/php/etc/php.d/
ADD extfile/ /data/phpext/

#Update nginx config
ADD nginx.conf /usr/local/nginx/conf/

#Start
RUN echo "- - - = = =  Finishing  = = = - - - "
ADD start.sh /
RUN chmod +x /start.sh

#Set port
EXPOSE 8080 443443

#Start it
ENTRYPOINT ["/start.sh"]

#Start web server
#CMD ["/bin/bash", "/start.sh"]
