#!/usr/bin/env bash

#### halt script on error
set -xe

git clone -b v10.0 https://github.com/laradock/laradock.git
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


    # sed -i -- 's/CHANGE_SOURCE=true/CHANGE_SOURCE=false/g' .env


    ### 自定义部分 ###

    # 开启 中国源-阿里云
    sed -i -- 's/CHANGE_SOURCE=false/CHANGE_SOURCE=true/g' .env

    # 开启 ffmpeg 安装 (php-fpm php-worker workspace)
    sed -i -- 's/PHP_FPM_FFMPEG=false/PHP_FPM_FFMPEG=true/g' .env
    sed -i -- 's/PHP_WORKER_INSTALL_FFMPEG=false/PHP_WORKER_INSTALL_FFMPEG=true/g' .env
    sed -i -- 's/WORKSPACE_INSTALL_FFMPEG=false/WORKSPACE_INSTALL_FFMPEG=true/g' .env

    # 开启 swoole 安装 (php-fpm php-worker workspace)
    sed -i -- 's/PHP_FPM_INSTALL_SWOOLE=false/PHP_FPM_INSTALL_SWOOLE=true/g' .env
    sed -i -- 's/PHP_WORKER_INSTALL_SWOOLE=false/PHP_WORKER_INSTALL_SWOOLE=true/g' .env
    sed -i -- 's/WORKSPACE_INSTALL_SWOOLE=false/WORKSPACE_INSTALL_SWOOLE=true/g' .env

    # 添加 php ini 配置文件至 php-fpm 镜像内

    search='USER root';
    insert='COPY ./php-fpm/php${LARADOCK_PHP_VERSION}.ini /usr/local/etc/php/php.ini';
    sed  -i "/$search/i$insert" ./php-fpm/Dockerfile;


fi


# 锁定 mysql 版本为 mysql 8.0
sed -i -- 's/MYSQL_VERSION=latest/MYSQL_VERSION=8.0/g' .env
#################

echo  build version is ${BUILD_VERSION}
cat .env

docker-compose build ${BUILD_SERVICE}
docker images

# push latest
docker tag laradock_${BUILD_SERVICE}:latest ${DOCKER_USERNAME}/laradock-${BUILD_SERVICE}:latest

docker images

docker push ${DOCKER_USERNAME}/laradock-${BUILD_SERVICE}

if [[ ${BUILD_VERSION} != "latest" ]]; then
    # push build version
    docker tag ${DOCKER_USERNAME}/laradock-${BUILD_SERVICE}:latest ${DOCKER_USERNAME}/laradock-${BUILD_SERVICE}:${BUILD_VERSION}
    docker push ${DOCKER_USERNAME}/laradock-${BUILD_SERVICE}
fi


#### Generate the Laradock Documentation site using Hugo
if [ -n "${HUGO_VERSION}" ]; then
    HUGO_PACKAGE=hugo_${HUGO_VERSION}_Linux-64bit
    HUGO_BIN=hugo_${HUGO_VERSION}_linux_amd64

    # Download hugo binary
    curl -L https://github.com/spf13/hugo/releases/download/v$HUGO_VERSION/$HUGO_PACKAGE.tar.gz | tar xz
    mkdir -p $HOME/bin
    mv ./${HUGO_BIN}/${HUGO_BIN} $HOME/bin/hugo

    # Remove existing docs
    if [ -d "./docs" ]; then
        rm -r ./docs
    fi

    # Build docs
    cd DOCUMENTATION
    hugo
fi
