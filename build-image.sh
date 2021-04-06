#!/usr/bin/env bash

#### halt script on error
set -xe

git clone -b v11.0 https://github.com/laradock/laradock.git
cd laradock

echo '##### Print docker version'
docker --version

echo '##### Print environment'
env | sort

BUILD_VERSION=latest
cp env-example .env

#### Build the Docker Images
if [ -n "${PHP_VERSION}" ]; then
    BUILD_VERSION=${PHP_VERSION}

    sed -i -- "s/PHP_VERSION=.*/PHP_VERSION=${PHP_VERSION}/g" .env
    # sed -i -- 's/=false/=true/g' .env
    sed -i -- 's/PHPDBG=true/PHPDBG=false/g' .env

    if [ "${PHP_VERSION}" == "5.6" ]; then
        # Aerospike C Client SDK 4.0.7, Debian 9.6 is not supported
        # https://github.com/aerospike/aerospike-client-php5/issues/145
        sed -i -- 's/PHP_FPM_INSTALL_AEROSPIKE=true/PHP_FPM_INSTALL_AEROSPIKE=false/g' .env

        sed -i -- 's/WORKSPACE_INSTALL_AST=true/WORKSPACE_INSTALL_AST=false/g' .env

        search='pecl install memcached';
        replace='pecl install memcached-2.2.0';
        sed  -i "s/$search/$replace/g" ./php-worker/Dockerfile;


        search='pecl install -o -f redis';
        replace='pecl install -o -f redis-2.2.8';
        sed  -i "s/$search/$replace/g" ./php-worker/Dockerfile;

        search='pecl -q install swoole-2.0.10;';
        insert='apk add linux-headers; \\';
        sed  -i "/$search/i$insert" ./php-worker/Dockerfile;
    fi

    if [ "${PHP_VERSION}" == "7.1" ]; then
        search='pecl install swoole; ';
        replace='pecl install swoole-2.2.0;';
        sed  -i "s/$search/$replace/g" ./php-fpm/Dockerfile;
        sed  -i "s/$search/$replace/g" ./php-worker/Dockerfile;
        sed  -i "s/$search/$replace/g" ./workspace/Dockerfile;
    fi

    if [ "${PHP_VERSION}" == "7.3" ]; then
        # V8JS extension does not yet support PHP 7.3.
        sed -i -- 's/WORKSPACE_INSTALL_V8JS=true/WORKSPACE_INSTALL_V8JS=false/g' .env
        # This ssh2 extension does not yet support PHP 7.3.
        sed -i -- 's/PHP_FPM_INSTALL_SSH2=true/PHP_FPM_INSTALL_SSH2=false/g' .env
        # xdebug extension does not yet support PHP 7.3.
        sed -i -- 's/PHP_FPM_INSTALL_XDEBUG=true/PHP_FPM_INSTALL_XDEBUG=false/g' .env
        # memcached extension does not yet support PHP 7.3.
        sed -i -- 's/PHP_FPM_INSTALL_MEMCACHED=true/PHP_FPM_INSTALL_MEMCACHED=false/g' .env
    fi

    if [ "${PHP_VERSION}" == "7.4" ]; then
        search='docker-php-ext-configure gd --with-freetype-dir=/usr/lib/ --with-jpeg-dir=/usr/lib/ --with-png-dir=/usr/lib/ ';
        replace='docker-php-ext-configure gd --with-freetype --with-jpeg ';
        sed -i "s|$search|$replace|g" ./php-worker/Dockerfile

    fi

    # sed -i -- 's/CHANGE_SOURCE=true/CHANGE_SOURCE=false/g' .env

    ### 自定义部分 ###

    # 开启 中国源-阿里云
    sed -i -- 's/CHANGE_SOURCE=false/CHANGE_SOURCE=true/g' .env

    # 开启 ffmpeg 安装 (php-fpm php-worker workspace)
    sed -i -- 's/PHP_FPM_FFMPEG=false/PHP_FPM_FFMPEG=true/g' .env
    sed -i -- 's/PHP_WORKER_INSTALL_FFMPEG=false/PHP_WORKER_INSTALL_FFMPEG=true/g' .env
    sed -i -- 's/WORKSPACE_INSTALL_FFMPEG=false/WORKSPACE_INSTALL_FFMPEG=true/g' .env

    # 开启 redis 扩展
    sed -i -- 's/PHP_WORKER_INSTALL_REDIS=false/PHP_WORKER_INSTALL_REDIS=true/g' .env

    # 开启 bcmath 扩展
    sed -i -- 's/PHP_WORKER_INSTALL_BCMATH=false/PHP_WORKER_INSTALL_BCMATH=true/g' .env

    # 开启 swoole 安装 (php-fpm php-worker workspace)
    sed -i -- 's/PHP_FPM_INSTALL_SWOOLE=false/PHP_FPM_INSTALL_SWOOLE=true/g' .env
    sed -i -- 's/PHP_WORKER_INSTALL_SWOOLE=false/PHP_WORKER_INSTALL_SWOOLE=true/g' .env
    sed -i -- 's/WORKSPACE_INSTALL_SWOOLE=false/WORKSPACE_INSTALL_SWOOLE=true/g' .env

    # 开启 GD 和 ImageMagic
    sed -i -- 's/PHP_WORKER_INSTALL_GD=false/PHP_WORKER_INSTALL_GD=true/g' .env
    sed -i -- 's/PHP_WORKER_INSTALL_IMAGEMAGICK=false/PHP_WORKER_INSTALL_IMAGEMAGICK=true/g' .env


    # 添加 php ini 配置文件至 php-fpm 镜像内

    search='xlaravel.pool.conf';
    insert='COPY php${LARADOCK_PHP_VERSION}.ini /usr/local/etc/php/php.ini';
    sed  -i "/$search/a$insert" ./php-fpm/Dockerfile;
fi


if [ "${BUILD_SERVICE}" == "nginx" ]; then
    # 拷贝 nginx 默认配置文件
    search='COPY nginx.conf';
    insert='COPY sites /etc/nginx/sites-available';
    sed  -i "/$search/a$insert" ./nginx/Dockerfile;
fi


if [ -n "${MYSQL_VERSION}" ]; then
    sed -i -- "s/MYSQL_VERSION=.*/MYSQL_VERSION=${MYSQL_VERSION}/g" .env
    BUILD_VERSION=${MYSQL_VERSION}
fi

echo  build version is ${BUILD_VERSION}
cat .env

docker-compose build ${BUILD_SERVICE}
#####################################

# push to docker hub
echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin

docker tag laradock_${BUILD_SERVICE}:latest ${DOCKER_USERNAME}/laradock-${BUILD_SERVICE}:latest

docker images

docker push ${DOCKER_USERNAME}/laradock-${BUILD_SERVICE}

if [[ ${BUILD_VERSION} != "latest" && ${BUILD_VERSION} != "NA" ]]; then
    # push build version
    docker tag ${DOCKER_USERNAME}/laradock-${BUILD_SERVICE}:latest ${DOCKER_USERNAME}/laradock-${BUILD_SERVICE}:${BUILD_VERSION}
    docker push ${DOCKER_USERNAME}/laradock-${BUILD_SERVICE}:${BUILD_VERSION}
fi


# push to aliyun docker hub
echo "$ALIYUN_DOCKER_PASSWORD" | docker login -u "$ALIYUN_DOCKER_USERNAME" --password-stdin registry.cn-hangzhou.aliyuncs.com

docker tag laradock_${BUILD_SERVICE}:latest registry.cn-hangzhou.aliyuncs.com/${DOCKER_USERNAME}/laradock-${BUILD_SERVICE}:latest

docker images

docker push registry.cn-hangzhou.aliyuncs.com/${DOCKER_USERNAME}/laradock-${BUILD_SERVICE}

if [[ ${BUILD_VERSION} != "latest" && ${BUILD_VERSION} != "NA" ]]; then
    # push build version
    docker tag ${DOCKER_USERNAME}/laradock-${BUILD_SERVICE}:latest registry.cn-hangzhou.aliyuncs.com/${DOCKER_USERNAME}/laradock-${BUILD_SERVICE}:${BUILD_VERSION}
    docker push registry.cn-hangzhou.aliyuncs.com/${DOCKER_USERNAME}/laradock-${BUILD_SERVICE}:${BUILD_VERSION}
fi
