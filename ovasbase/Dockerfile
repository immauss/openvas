FROM debian:buster
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
COPY install-deps-buster.sh /
COPY package-list-buster /
RUN bash /install-deps-buster.sh
ENTRYPOINT ["/bin/bash"] 
