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
COPY build.d/* /build.d/
COPY build.rc /
COPY package-list-buster-build /
RUN bash /build.d/build-prereqs.sh
RUN bash /build.d/update-certs.sh
RUN bash /build.d/gvm-libs.sh
RUN bash /build.d/openvas-smb.sh
RUN bash /build.d/gvmd.sh
RUN bash /build.d/openvas-scanner.sh
RUN bash /build.d/gsa.sh
RUN bash /build.d/ospd.sh
RUN bash /build.d/ospd-openvas.sh
RUN bash /build.d/gvm-tool.sh
RUN bash /build.d/links.sh

# Stage 1: Start again with the ovasebase. Dependancies already installed
FROM immauss/ovasbase:latest
LABEL maintainer="scott@immauss.com" \
      version="21.04.04" \
      url="https://hub.docker.com/immauss/openvas" \
      source="https://github.com/immauss/openvas"
      
      
EXPOSE 9392
ENV LANG=C.UTF-8
# Copy the install from stage 0
COPY --from=0 /usr/local /usr/local

RUN ldconfig
# Split these off in a new layer makes refresh builds faster.
COPY update.ts /
RUN curl -L --url https://www.immauss.com/openvas/base.sql.xz -o /usr/lib/base.sql.xz && \
    curl -L --url https://www.immauss.com/openvas/var-lib.tar.xz -o /usr/lib/var-lib.tar.xz
# Make sure we didn't just pull zero length files 
RUN bash -c " if [ $(ls -l /usr/lib/base.sql.xz | awk '{print $5}') -lt 1200 ]; then exit 1; fi "
RUN bash -c " if [ $(ls -l /usr/lib/var-lib.tar.xz | awk '{print $5}') -lt 1200 ]; then exit 1; fi "

COPY scripts/* /
HEALTHCHECK --interval=600s --start-period=1200s --timeout=3s \
  CMD curl -f http://localhost:9392/ || exit 1
CMD [ "/start.sh" ]
