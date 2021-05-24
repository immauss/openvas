# Stage 0: Start with a squashed fully updated ubuntu:20.04
# This is created seperately.
FROM immauss/ovas-base:20.04u
# Build date: 25 Feb 2021:wq
#
# Ensure apt doesn't ask any questions 
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8

# Build/install gvm (by default, everything installs in /usr/local)
# Broken in to seperate RUNs to speed up rebuilds during beta testing
COPY build-setup.sh /build-setup.sh
RUN /build-setup.sh
COPY build.d/01-gvm-libs.sh /build.d/
RUN /build.d/01-gvm-libs.sh  
COPY build.d/02-openvas-smb.sh /build.d/
RUN /build.d/02-openvas-smb.sh  
COPY build.d/03-gvmd.sh /build.d/
RUN /build.d/03-gvmd.sh  
COPY build.d/04-openvas-scanner.sh /build.d/
RUN /build.d/04-openvas-scanner.sh  
COPY build.d/05-gsa.sh /build.d/
RUN /build.d/05-gsa.sh  
COPY build.d/06-python-gvm.sh /build.d/
RUN /build.d/06-python-gvm.sh  
COPY build.d/07-ospd.sh  /build.d/
RUN /build.d/07-ospd.sh  
COPY build.d/08-ospd-openvas.sh /build.d/
RUN /build.d/08-ospd-openvas.sh
COPY build.d/09-gvm-tools.sh /build.d/
RUN /build.d/09-gvm-tools.sh
COPY build.d/10-pg-gvm.sh /build.d/
RUN /build.d/10-pg-gvm.sh
COPY build.d/10-link.sh /build.d/
RUN /build.d/10-link.sh

# Stage 1: Start again with the squashed fully updated ubuntu:20.04
FROM immauss/ovas-base:20.04u
LABEL maintainer="scott@immauss.com" \
      version="20.08.4" \
      url="https://hub.docker.com/immauss/openvas" \
      source="https://github.com/immauss/openvas"
      
      
EXPOSE 9392
ENV LANG=C.UTF-8
# Ensure apt doesn't ask any questions 
ENV DEBIAN_FRONTEND=noninteractive
# Install the dependencies
RUN apt-get update && apt-get install -yq --no-install-recommends xz-utils ca-certificates curl doxygen geoip-database gnutls-bin graphviz ike-scan libmicrohttpd12 libnet1 libhdb9-heimdal libsnmp35 libssh-gcrypt-4 libical3 libgpgme11 libnet-snmp-perl locales-all mailutils net-tools nmap nsis openssh-client openssh-server perl-base pkg-config postfix postgresql-12 python3-defusedxml python3-dialog python3-lxml python3-paramiko python3-pip python3-polib python3-psutil python3-setuptools redis-server redis-tools rsync smbclient sshpass texlive-fonts-recommended texlive-latex-extra wapiti wget whiptail xml-twig-tools xsltproc && \
apt-get clean && \
mkdir -p /usr/local/lib 
COPY .base-ts /

# Copy the install from stage 0 and make sure they are linked properly
COPY --from=0 /usr/local /usr/local
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/openvas.conf && \
ldconfig 

COPY update-base.sh /
RUN /update-base.sh
COPY scripts/* /
# Setting the start-period to 20 minutes should give enough time to sync the NVTs
HEALTHCHECK --interval=600s --start-period=1200s --timeout=3s \
  CMD curl -f http://localhost:9392/ || exit 1
#CMD [ "/start.sh" ]
ENTRYPOINT [ "/start.sh" ]
