# Stage 0: 
# Start with ovasbase with running dependancies installed.
FROM immauss/ovasbase:latest AS Builder

# Ensure apt doesn't ask any questions 
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8

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
COPY build.d/gsa.sh /build.d/
RUN bash /build.d/gsa.sh
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
COPY build.d/links.sh /build.d/
RUN bash /build.d/links.sh
RUN mkdir /branding
COPY branding/* /branding/
RUN bash /branding/branding.sh
# Stage 1: Start again with the ovasbase. Dependancies already installed
FROM immauss/ovasbase:latest AS installed
LABEL maintainer="scott@immauss.com" \
      version="22.4.15" \
      url="https://hub.docker.com/r/immauss/openvas" \
      source="https://github.com/immauss/openvas"
      
      
#EXPOSE 9392
ENV LANG=C.UTF-8
# Copy the install from stage 0
COPY --from=0 etc/gvm/pwpolicy.conf /usr/local/etc/gvm/pwpolicy.conf
COPY --from=0 etc/logrotate.d/gvmd /etc/logrotate.d/gvmd
COPY --from=0 lib/systemd/system /lib/systemd/system
COPY --from=0 usr/local/bin /usr/local/bin
COPY --from=0 usr/local/include /usr/local/include
COPY --from=0 usr/local/lib /usr/local/lib
COPY --from=0 usr/local/sbin /usr/local/sbin
COPY --from=0 usr/local/share /usr/local/share
COPY --from=0 usr/share/postgresql /usr/share/postgresql
COPY --from=0 usr/lib/postgresql /usr/lib/postgresql
COPY confs/gvmd_log.conf /usr/local/etc/gvm/
COPY confs/openvas_log.conf /usr/local/etc/openvas/
COPY build.d/links.sh /
RUN bash /links.sh 
COPY build.d/gpg-keys.sh /
RUN bash /gpg-keys.sh
# Split these off in a new layer makes refresh builds faster.
COPY build.rc /gvm-versions
# Pull and then Make sure we didn't just pull zero length files 

RUN curl -L --url https://www.immauss.com/openvas/latest.base.sql.xz -o /usr/lib/base.sql.xz && \
    curl -L --url https://www.immauss.com/openvas/latest.var-lib.tar.xz -o /usr/lib/var-lib.tar.xz && \
    bash -c " if [ $(ls -l /usr/lib/base.sql.xz | awk '{print $5}') -lt 1200 ]; then exit 1; fi " && \
    bash -c " if [ $(ls -l /usr/lib/var-lib.tar.xz | awk '{print $5}') -lt 1200 ]; then exit 1; fi "

# packages to add to ovasbase
#RUN apt-get update && apt-get -y install libpaho-mqtt-dev python3-paho-mqtt gir1.2-json-1.0 libjson-glib-1.0-0 libjson-glib-1.0-common
COPY scripts/* /scripts/
# Healthcheck needs be an on image script that will know what service is running and check it. 
# Current image function stored in /usr/local/etc/running-as
HEALTHCHECK --interval=60s --start-period=300s --timeout=10s \
  CMD /scripts/healthcheck.sh || exit 1
ENTRYPOINT [ "/scripts/start.sh" ]
