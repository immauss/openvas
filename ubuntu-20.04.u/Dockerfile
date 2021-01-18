FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
RUN  apt update && apt upgrade -y && apt autoremove && apt-get clean
ENTRYPOINT ["/bin/bash"] 
