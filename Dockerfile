# Environment variables for all

# Stage 0: 
# Start with ovasbase with running dependancies installed.
FROM immauss/ovasbase:latest AS builder

# Ensure apt doesn't ask any questions 
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ARG TAG
ENV VER="$TAG"

# Build/install gvm (by default, everything installs in /usr/local)
RUN mkdir /build.d
COPY build.rc /
COPY package-list-build /
COPY build.d/build-prereqs.sh /build.d/
RUN bash /build.d/build-prereqs.sh
COPY build.d/update-certs.sh /build.d/
RUN bash /build.d/update-certs.sh
COPY build.d/gvm-libs.sh /build.d/
RUN bash /build.d/gvm-libs.sh
COPY build.d/openvas-smb.sh /build.d/
RUN bash /build.d/openvas-smb.sh
COPY build.d/gvmd.sh /build.d/
RUN bash /build.d/gvmd.sh
COPY build.d/openvas-scanner.sh /build.d/
RUN bash /build.d/openvas-scanner.sh

COPY build.d/ospd-openvas.sh /build.d/
RUN bash /build.d/ospd-openvas.sh
COPY build.d/gvm-tool.sh /build.d/
RUN bash /build.d/gvm-tool.sh
COPY build.d/notus-scanner.sh /build.d/
RUN bash /build.d/notus-scanner.sh
COPY build.d/pg-gvm.sh /build.d/
RUN bash /build.d/pg-gvm.sh
COPY build.d/gb-feed-sync.sh /build.d/
RUN bash /build.d/gb-feed-sync.sh

#COPY build.d/gsa.sh /build.d/
COPY ics-gsa /ics-gsa
#RUN bash /build.d/gsa.sh
COPY build.d/gsad.sh /build.d
RUN bash /build.d/gsad.sh

COPY build.d/links.sh /build.d/
RUN bash /build.d/links.sh
RUN mkdir /branding 
COPY build.d/coallate.sh /
RUN bash /coallate.sh 

# Stage 1: Start again with the ovasbase. Dependancies already installed
# This target is for the image with no database
# Makes rebuilds for data refresh and scripting changes faster. 
FROM immauss/ovasbase:latest AS slim
LABEL maintainer="scott@immauss.com" \
      version="$VER-slim" \
      url="https://hub.docker.com/r/immauss/openvas" \
      source="https://github.com/immauss/openvas"     
#EXPOSE 9392
ENV LANG=C.UTF-8
# Copy the install from stage 0
# Move all of this to a sinlge "build" folder and reduce the number of layers by copying the 
# entire folder in one line to root/ 
#COPY --from=0 etc/gvm/pwpolicy.conf /usr/local/etc/gvm/pwpolicy.conf
#COPY --from=0 etc/logrotate.d/gvmd /etc/logrotate.d/gvmd
#COPY --from=0 lib/systemd/system /lib/systemd/system
#COPY --from=0 usr/local/bin /usr/local/bin
#COPY --from=0 usr/local/include /usr/local/include
#COPY --from=0 usr/local/lib /usr/local/lib
#COPY --from=0 usr/local/sbin /usr/local/sbin
#COPY --from=0 usr/local/share /usr/local/share
#COPY --from=0 usr/share/postgresql /usr/share/postgresql
#COPY --from=0 usr/lib/postgresql /usr/lib/postgresql
COPY --from=0 /final .

COPY confs/* /usr/local/etc/gvm/
COPY build.d/links.sh /
RUN bash /links.sh 
COPY build.d/gpg-keys.sh /
RUN bash /gpg-keys.sh
# Copy in the prebuilt gsa react code.
COPY gsa-final/ /usr/local/share/gvm/gsad/web/
COPY build.rc /gvm-versions
COPY branding/* /branding/
RUN bash /branding/branding.sh
COPY scripts/* /scripts/
RUN apt update && apt install libcap2-bin net-tools -y 
# allow openvas to access raw sockets and all kind of network related tasks
RUN setcap cap_net_raw,cap_net_admin+eip /usr/local/sbin/openvas
# allow nmap to send e.g. UDP or TCP SYN probes without root permissions
ENV NMAP_PRIVILEGED=1
RUN setcap cap_net_raw,cap_net_admin,cap_net_bind_service+eip /usr/bin/nmap

# Healthcheck needs be an on image script that will know what service is running and check it. 
# Current image function stored in /usr/local/etc/running-as
HEALTHCHECK --interval=60s --start-period=300s --timeout=10s \
  CMD /scripts/healthcheck.sh || exit 1
ENTRYPOINT [ "/scripts/start.sh" ]

FROM slim AS final
LABEL maintainer="scott@immauss.com" \
      version="$VER-full" \
      url="https://hub.docker.com/r/immauss/openvas" \
      source="https://github.com/immauss/openvas"

COPY base.sql.xz /usr/lib/base.sql.xz
COPY var-lib.tar.xz /usr/lib/var-lib.tar.xz
# packages to add to ovasbase
#RUN apt-get update && apt-get -y install libpaho-mqtt-dev python3-paho-mqtt gir1.2-json-1.0 libjson-glib-1.0-0 libjson-glib-1.0-common
COPY scripts/* /scripts/
RUN apt update && apt -y install libical3 libpaho-mqtt1.3 libradcli4 libssh-gcrypt-4 libhiredis0.14
# Healthcheck needs be an on image script that will know what service is running and check it. 
# Current image function stored in /usr/local/etc/running-as
HEALTHCHECK --interval=300s --start-period=300s --timeout=120s \
  CMD /scripts/healthcheck.sh || exit 1
ENTRYPOINT [ "/scripts/start.sh" ]
