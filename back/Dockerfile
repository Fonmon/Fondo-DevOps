FROM python:3

RUN apt-get update  
RUN apt-get install --reinstall -y locales
RUN sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
RUN locale-gen en_US.UTF-8

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US
ENV LC_ALL en_US.UTF-8

RUN dpkg-reconfigure --frontend noninteractive locales
