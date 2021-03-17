#!/bin/sh

deploy() {}
    COMPOSE_FILE=app.yml
    SVC="$1"
    env
        ALLOW_BUILD_TRIGGERS=false \
        ALLOW_TWITTER_POSTS=false \
        BUILD_TRIGGER_DOWNSCALING=1 \
        BUILD_TRIGGER_LIMIT=10 \
        BUILD_TRIGGER_SLEEP=60 \
        BUILDER_TOKEN=foo \
        CHECKOUTS_DIR=checkouts \
        DATABASE_HOST=172.17.0.1 \
        DATABASE_PORT=6432 \
        DATABASE_NAME=spi_dev \
        DATABASE_USERNAME=spi_dev \
        DATABASE_PASSWORD=xxx \
        GITHUB_TOKEN=foo \
        GITLAB_API_TOKEN=foo \
        GITLAB_PIPELINE_LIMIT=100 \
        GITLAB_PIPELINE_TOKEN=foo \
        HIDE_STAGING_BANNER=false \
        LOG_LEVEL=info \
        METRICS_PUSHGATEWAY_URL=http://127.0.0.1:9091 \
        ROLLBAR_TOKEN=foo \
        SITE_URL=http://127.0.0.1:8080 \
        TWITTER_API_KEY=foo \
        TWITTER_API_SECRET=foo \
        TWITTER_ACCESS_TOKEN_KEY=foo \
        TWITTER_ACCESS_TOKEN_SECRET=foo \
    docker stack deploy -c $COMPOSE_FILE $SVC

deploy app

# docker stack deploy -c app.yml db
# docker stack deploy -c app.yml migrate
# docker stack deploy -c app.yml app ...
