FROM centos:latest

RUN yum install -y make gcc libaio perl perl-ExtUtils-MakeMaker perl-Data-Dumper
RUN curl -L https://cpanmin.us | perl - App::cpanminus

RUN mkdir -p /opt/zdba
WORKDIR /opt/zdba

COPY cpanfile .
RUN cpanm --installdeps .

COPY . /opt/zdba