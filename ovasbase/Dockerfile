FROM debian:buster
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
COPY scripts /scripts
RUN bash /scripts/install-deps-buster.sh && \
 bash /scripts/stage2-setup.sh
ENTRYPOINT ["/bin/bash"] 
