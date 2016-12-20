FROM netrusov/zdba:base

RUN apk add --no-cache postgresql-dev

RUN apk add --no-cache --virtual .builddeps $BUILD_DEPS && \
    cpanm DBD::Pg && \
    rm -rf /root/.cpanm/work && \
    apk del .builddeps
