# Stage 0: 
# Start with ovasbase with running dependancies installed.
FROM immauss/ovasbase:latest

# Ensure apt doesn't ask any questions 
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8

# Build/install gvm (by default, everything installs in /usr/local)
#COPY install-build-deps.sh /install-build-deps.sh
#COPY package-list-building /package-list-building
#RUN bash /install-build-deps.sh
RUN mkdir /build.d
#COPY build.d/* /build.d/
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
COPY build.d/ospd.sh /build.d/
RUN bash /build.d/ospd.sh
COPY build.d/ospd-openvas.sh /build.d/
RUN bash /build.d/ospd-openvas.sh
COPY build.d/gvm-tool.sh /build.d/
RUN bash /build.d/gvm-tool.sh
COPY build.d/links.sh /build.d/
RUN bash /build.d/links.sh

# Stage 1: Start again with the ovasebase. Dependancies already installed
FROM immauss/ovasbase:latest
LABEL maintainer="scott@immauss.com" \
      version="21.4.4" \
      url="https://hub.docker.com/immauss/openvas" \
      source="https://github.com/immauss/openvas"
      
      
EXPOSE 9392
ENV LANG=C.UTF-8
# Copy the install from stage 0
COPY --from=0 /usr/local /usr/local
COPY --from=0 /var/lib /var/lib 
COPY --from=0 /etc/gvm /etc/gvm

RUN ldconfig
# Split these off in a new layer makes refresh builds faster.
COPY update.ts /
RUN curl -L --url https://www.immauss.com/openvas/base.sql.xz -o /usr/lib/base.sql.xz && \
    curl -L --url https://www.immauss.com/openvas/var-lib.tar.xz -o /usr/lib/var-lib.tar.xz
# Make sure we didn't just pull zero length files 
RUN bash -c " if [ $(ls -l /usr/lib/base.sql.xz | awk '{print $5}') -lt 1200 ]; then exit 1; fi "
RUN bash -c " if [ $(ls -l /usr/lib/var-lib.tar.xz | awk '{print $5}') -lt 1200 ]; then exit 1; fi "
RUN mkdir /scripts
COPY scripts/* /scripts/
RUN bash scripts/stage2-setup.sh
# Healthcheck needs be an on image script that will know what service is running and check it. 
# Current image function stored in /usr/local/etc/running-as
#HEALTHCHECK --interval=600s --start-period=1200s --timeout=3s \
  #CMD /scripts/healthcheck.sh || exit 1
ENTRYPOINT [ "/scripts/start.sh" ]
