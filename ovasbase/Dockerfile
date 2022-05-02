FROM debian:bullseye
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
COPY scripts /scripts
#COPY sources.list /etc/apt/
RUN bash /scripts/install-deps.sh && \
 date > /ovasbase-build-date
ENTRYPOINT ["/bin/bash"] 
