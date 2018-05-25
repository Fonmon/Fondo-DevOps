FROM python:3

RUN apt-get update  
RUN apt-get install --reinstall -y locales
RUN sed -i 's/# es_CO.UTF-8 UTF-8/es_CO.UTF-8 UTF-8/' /etc/locale.gen
RUN locale-gen es_CO.UTF-8

ENV LANG es_CO.UTF-8
ENV LANGUAGE es_CO.UTF-8
ENV LC_ALL es_CO.UTF-8

RUN dpkg-reconfigure --frontend noninteractive locales

WORKDIR /app

COPY . /app

EXPOSE 8443

CMD sh scripts/run-server.sh
