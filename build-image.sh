#!/usr/bin/env bash

#### halt script on error
set -xe

#git clone -b v12.1 https://github.com/laradock/laradock.git
git clone  https://github.com/laradock/laradock.git
cd laradock
# switch version to Commits on Dec 22, 2022
git checkout 6c8cb6dd85eb1fcad6f7dce3e9d6c6a29c6e3ed8

echo '##### Print docker version'
docker --version

echo '##### Print environment'
env | sort

BUILD_VERSION=latest
cp .env.example .env

# 检查sed命令兼容性
if [[ `uname` == 'Darwin' ]]; then
    # macOS使用gsed（如果安装了的话）
    if command -v gsed > /dev/null 2>&1; then
        alias sed=gsed;
    fi
elif [[ `uname` == 'Linux' ]]; then
    # Linux环境使用默认sed
    echo "Linux环境，使用系统自带sed"
fi

#### Build the Docker Images
if [ -n "${PHP_VERSION}" ]; then
    BUILD_VERSION=${PHP_VERSION}

    sed -i -- "s/PHP_VERSION=.*/PHP_VERSION=${PHP_VERSION}/g" .env
    # sed -i -- 's/=false/=true/g' .env
    sed -i -- 's/PHPDBG=true/PHPDBG=false/g' .env

    if [[ "${PHP_VERSION}" == "7.2" || "${PHP_VERSION}" == "7.3" || "${PHP_VERSION}" == "7.4" ]]; then
        # V8JS extension does not yet support PHP 7.3.
        sed -i -- 's/WORKSPACE_INSTALL_V8JS=true/WORKSPACE_INSTALL_V8JS=false/g' .env
        # This ssh2 extension does not yet support PHP 7.3.
        sed -i -- 's/PHP_FPM_INSTALL_SSH2=true/PHP_FPM_INSTALL_SSH2=false/g' .env
        # xdebug extension does not yet support PHP 7.3.
        sed -i -- 's/PHP_FPM_INSTALL_XDEBUG=true/PHP_FPM_INSTALL_XDEBUG=false/g' .env
        # memcached extension does not yet support PHP 7.3.
        sed -i -- 's/PHP_FPM_INSTALL_MEMCACHED=true/PHP_FPM_INSTALL_MEMCACHED=false/g' .env

        search='pecl -q install swoole;';
        replace='pecl -q install swoole-4.8.9;';
        sed -i "s/$search/$replace/g" ./workspace/Dockerfile;

        search='pecl install swoole;';
        replace='pecl install swoole-4.8.9;';
        sed -i "s/$search/$replace/g" ./php-fpm/Dockerfile;
        sed -i "s/$search/$replace/g" ./php-worker/Dockerfile;
    fi

    if [ "${PHP_VERSION}" == "8.0" ]; then
        search='pecl -q install swoole;';
        replace="yes yes | pecl install swoole-4.8.10;";
        sed -i "s/^$search/^$replace/g" ./workspace/Dockerfile;
    fi

    if [[ "${PHP_VERSION}" == "8.1" || "${PHP_VERSION}" == "8.2" || "${PHP_VERSION}" == "8.3" ]]; then
        search='pecl -q install swoole;';
        replace="yes yes | pecl install swoole-5.1.8;";
        sed -i "s/$search/$replace/g" ./workspace/Dockerfile;

        search='pecl install swoole;';
        replace="yes yes | pecl install swoole-5.1.8;";
        sed -i "s/$search/$replace/g" ./php-fpm/Dockerfile;
        sed -i "s/$search/$replace/g" ./php-worker/Dockerfile;
    fi
    
    # if [ "${PHP_VERSION}" == "7.4" ]; then
    #     search='docker-php-ext-configure gd --with-freetype-dir=/usr/lib/ --with-jpeg-dir=/usr/lib/ --with-png-dir=/usr/lib/ ';
    #     replace='docker-php-ext-configure gd --with-freetype --with-jpeg ';
    #     sed -i "s|$search|$replace|g" ./php-worker/Dockerfile

    #     # https://github.com/docker-library/php/issues/225#issuecomment-691989156
    #     search='apk add --update --no-cache freetype-dev libjpeg-turbo-dev jpeg-dev libpng-dev;';
    #     replace='apk add --no-cache freetype freetype-dev libpng libpng-dev libjpeg-turbo libjpeg-turbo-dev;';
    #     sed -i "s|$search|$replace|g" ./php-worker/Dockerfile
    # fi

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

    # 开启 RabbitMQ 支持
    sed -i -- 's/PHP_FPM_INSTALL_AMQP=false/PHP_FPM_INSTALL_AMQP=true/g' .env
    sed -i -- 's/WORKSPACE_INSTALL_AMQP=false/WORKSPACE_INSTALL_AMQP=true/g' .env

    # 开启 MongoDB 支持
    sed -i -- 's/WORKSPACE_INSTALL_MONGO=false/WORKSPACE_INSTALL_MONGO=true/g' .env
    sed -i -- 's/PHP_FPM_INSTALL_MONGO=false/PHP_FPM_INSTALL_MONGO=true/g' .env
    sed -i -- 's/PHP_WORKER_INSTALL_MONGO=false/PHP_WORKER_INSTALL_MONGO=true/g' .env


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

# 检查并使用正确的docker compose命令
echo "=== 开始构建Docker镜像 ==="

# 构建重试函数
build_with_retry() {
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "构建尝试 $attempt/$max_attempts..."
        
        if docker compose version > /dev/null 2>&1; then
            echo "使用 docker compose (plugin) 构建镜像..."
            if timeout 3600 docker compose build --no-cache ${BUILD_SERVICE}; then
                echo "✅ 构建成功！"
                return 0
            fi
        elif docker-compose --version > /dev/null 2>&1; then
            echo "使用 docker-compose (standalone) 构建镜像..."
            if timeout 3600 docker-compose build --no-cache ${BUILD_SERVICE}; then
                echo "✅ 构建成功！"
                return 0
            fi
        else
            echo "❌ 错误: 找不到 docker compose 或 docker-compose 命令"
            exit 1
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            echo "⚠️  构建失败，等待30秒后重试..."
            sleep 30
            
            # 清理Docker缓存
            echo "清理Docker构建缓存..."
            docker builder prune -f || true
            docker system prune -f || true
        fi
        
        attempt=$((attempt + 1))
    done
    
    echo "❌ 所有构建尝试都失败了"
    return 1
}

# 执行构建
if build_with_retry; then
    echo "🎉 Docker镜像构建完成！"
else
    echo "💥 Docker镜像构建失败！"
    exit 1
fi
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
