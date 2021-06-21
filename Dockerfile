# Stage 0: Start with a squashed fully updated ubuntu:20.04
# This is created seperately.
FROM ubuntu:20.04

# Ensure apt doesn't ask any questions 
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8

# Build/install gvm (by default, everything installs in /usr/local)
COPY build-gvm.sh /build-gvm.sh
COPY build.rc /build.rc
RUN bash /build-gvm.sh

# Stage 1: Start again with the squashed fully updated ubuntu:20.04
FROM ubuntu:20.04
LABEL maintainer="scott@immauss.com" \
      version="21.04.02" \
      url="https://hub.docker.com/immauss/openvas" \
      source="https://github.com/immauss/openvas"
      
      
EXPOSE 9392
ENV LANG=C.UTF-8
# Ensure apt doesn't ask any questions 
ENV DEBIAN_FRONTEND=noninteractive
# Copy the install from stage 0
COPY --from=0 /usr/local /usr/local

# Install the dependencies
RUN apt-get update && \
apt-get install -y gnupg curl && \
echo "deb http://apt.postgresql.org/pub/repos/apt focal-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - &&  \
apt-get update && \
apt-get install -yq --no-install-recommends ca-certificates xz-utils curl doxygen geoip-database gnutls-bin graphviz ike-scan libmicrohttpd12 libhdb9-heimdal libsnmp35 libssh-gcrypt-4 libical3 libgpgme11 libnet1 libnet-snmp-perl libunistring2 locales-all mailutils net-tools nmap nsis openssh-client openssh-server perl-base pkg-config postfix postgresql-12 python3-psutil python3-defusedxml python3-dialog python3-lxml python3-paramiko python3-pip python3-polib python3-setuptools redis-server redis-tools rsync smbclient sshpass texlive-fonts-recommended texlive-latex-extra wapiti wget whiptail xml-twig-tools xsltproc && \
apt-get clean && \
echo "/usr/local/lib" > /etc/ld.so.conf.d/openvas.conf && \
ldconfig 
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
