# Stage 0: Start with a squashed fully updated ubuntu:20.04
# This is created seperately.
FROM ubuntu:20.04.u

# Ensure apt doesn't ask any questions 
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8

# Build/install gvm (by default, everything installs in /usr/local)
COPY build-gvm.sh /build-gvm.sh
RUN bash /build-gvm.sh

# Stage 1: Start again with the squashed fully updated ubuntu:20.04
FROM ubuntu:20.04.u
LABEL maintainer="scott@immauss.com" \
      version="20.08.02.3" \
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
apt-get install -yq --no-install-recommends ca-certificates curl geoip-database gnutls-bin graphviz ike-scan libmicrohttpd12 libhdb9-heimdal libsnmp35 libssh-gcrypt-4 libical3 libgpgme11 libnet-snmp-perl locales-all mailutils net-tools nmap nsis openssh-client openssh-server perl-base pkg-config postfix postgresql-12 python3-defusedxml python3-dialog python3-lxml python3-paramiko python3-pip python3-polib python3-setuptools redis-server redis-tools rsync smbclient sshpass texlive-fonts-recommended texlive-latex-extra wapiti wget whiptail xml-twig-tools xsltproc && \
python3 -m pip install psutil && \
apt-get clean && \
echo "/usr/local/lib" > /etc/ld.so.conf.d/openvas.conf && \
ldconfig


COPY scripts/* /
# Setting the start-period to 20 minutes should give enough time to sync the NVTs
HEALTHCHECK --interval=600s --start-period=1200s --timeout=3s \
  CMD curl -f http://localhost:9392/ || exit 1
ENTRYPOINT [ "/start.sh" ]
