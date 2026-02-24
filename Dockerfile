# Environment variables for all

# Stage 0: 
# Start with ovasbase with running dependancies installed.
FROM immauss/ovasbase:25.12 AS builder

# Ensure apt doesn't ask any questions 
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ARG TAG
ENV VER="$TAG"

# Build everything that requires a compiler here and install to /artifacts for copy to 2nd stage.
# we don't care about layer count here, in fact multiple layers helps when there are problems witha build
# as the previous layers will be cached and reduce build time when troubleshooing issues
RUN mkdir /build.d
COPY build.rc ver.current /
COPY build.d/package-list-build /build.d/
COPY build.d/env.sh /build.d
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
COPY build.d/pg-gvm.sh /build.d/
RUN bash /build.d/pg-gvm.sh
COPY ics-gsa /ics-gsa
COPY build.d/gsad.sh /build.d
RUN bash /build.d/gsad.sh
# Stage 1: Start again with the ovasbase. Dependancies already installed
# This target is for the image with no database
# Makes rebuilds for data refresh and scripting changes faster. 
FROM immauss/ovasbase:25.12 AS slim
LABEL maintainer="scott@immauss.com" \
      version="$VER-slim" \
      url="https://hub.docker.com/r/immauss/openvas" \
      source="https://github.com/immauss/openvas"     
EXPOSE 9392
ENV LANG=C.UTF-8
# Copy the just built from stage 0
COPY --from=builder /artifacts/. /

# The python bits. 
# these need to be rolled into a single layer that removes any excess bits. 
# create a single script that installs all the python stuffs and then deletes all the source.
# the gain for this will be minimal in size but will reduce layer count.
COPY build.rc ver.current /
RUN mkdir -p /build
COPY build.d/ospd-openvas.sh /build.d/. 
RUN bash /build.d/ospd-openvas.sh
COPY build.d/gvm-tool.sh /build.d/
RUN bash /build.d/gvm-tool.sh
COPY build.d/gb-feed-sync.sh /build.d/
RUN bash /build.d/gb-feed-sync.sh
# library links
COPY build.d/links.sh /build.d/
RUN bash /build.d/links.sh

# This needs consolidation
COPY confs/ /
COPY build.d/links.sh /
RUN bash /links.sh 
COPY build.d/gpg-keys.sh /
RUN bash /gpg-keys.sh
# Copy in the prebuilt gsa react code.
COPY gsa-final/ /usr/local/share/gvm/gsad/web/
COPY build.rc /gvm-versions
COPY branding/ /branding/
RUN bash /branding/branding.sh
COPY scripts/ /scripts/
COPY ver.current /
#RUN apt update && apt install libcap2-bin net-tools -y 
# allow openvas to access raw sockets and all kind of network related tasks
#RUN setcap cap_net_raw,cap_net_admin+eip /usr/local/sbin/openvas
# allow nmap to send e.g. UDP or TCP SYN probes without root permissions
#ENV NMAP_PRIVILEGED=1
#RUN setcap cap_net_raw,cap_net_admin,cap_net_bind_service+eip /usr/bin/nmap

# Healthcheck needs be an on image script that will know what service is running and check it. 
# Current image function stored in /usr/local/etc/running-as
HEALTHCHECK --interval=300s --start-period=300s --timeout=120s \
  CMD /scripts/healthcheck.sh || exit 1
ENTRYPOINT [ "/scripts/start.sh" ]

FROM slim AS final
LABEL maintainer="scott@immauss.com" \
      version="$VER-full" \
      url="https://hub.docker.com/r/immauss/openvas" \
      source="https://github.com/immauss/openvas"

COPY globals.sql.xz /usr/lib/globals.sql.xz
COPY gvmd.sql.xz /usr/lib/gvmd.sql.xz
COPY var-lib.tar.xz /usr/lib/var-lib.tar.xz
COPY scripts/* /scripts/
RUN apt-get update && apt-get install -y capnproto
RUN pip3 install redis==7.1.0 --break-system-packages
# Healthcheck needs be an on image script that will know what service is running and check it. 
# Current image function stored in /usr/local/etc/running-as
HEALTHCHECK --interval=300s --start-period=300s --timeout=120s \
  CMD /scripts/healthcheck.sh || exit 1
ENTRYPOINT [ "/scripts/start.sh" ]
