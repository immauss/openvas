FROM debian:buster
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
COPY scripts /scripts
RUN bash /scripts/install-deps-buster.sh && \
 date > /ovasbase-build-date
ENTRYPOINT ["/bin/bash"] 
