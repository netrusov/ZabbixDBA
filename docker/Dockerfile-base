FROM alpine:3.4

ENV DEPS='perl'
ENV BUILD_DEPS='curl wget make gcc libc-dev perl-dev'

RUN mkdir /zdba
WORKDIR /zdba

COPY cpanfile /zdba

RUN apk add --no-cache $DEPS

RUN set -ex && \
    apk add --no-cache --virtual .builddeps $BUILD_DEPS && \
    (curl -L https://cpanmin.us | perl - App::cpanminus) && \
    cpanm --installdeps . && \
    rm -rf /root/.cpanm/work && \
    apk del .builddeps

COPY . /zdba

VOLUME ["/zdba/conf", "/zdba/log"]

CMD ["/usr/bin/perl", "/zdba/zdba.pl", "/zdba/conf/config.pl"]
