FROM debian:12
ENV LANG=C.UTF-8
ENV DEBIAN_FRONTEND=noninteractive
COPY scripts /scripts
#COPY sources.list /etc/apt/
RUN bash /scripts/setup.sh && \
 date > /ovasbase-build-date
ENTRYPOINT ["/bin/bash"] 
