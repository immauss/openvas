#!/bin/bash 
# Put all the bits I need into the right place so I can move them all into
# the finall image in a single image layer

# Create the dir structure in "/final" 
mkdir -p /final/usr/local/etc/gvm /final/etc/gvm /final/etc/logrotate.d /final/usr/local/bin \
         /final/usr/local/include /final/usr/local/lib /final/usr/local/share /final/usr/share/postgresql \
         /final/usr/lib/postgresql /final/usr/local/sbin 

cp -rp /etc/gvm/* /final/etc/gvm/ 
cp -rp /etc/logrotate.d/gvmd /final/etc/logrotate.d/
#cp -rp /lib/systemd/system/* /final/lib/systemd/system/
cp -rp /usr/local/bin/* /final/usr/local/bin/
cp -rp /usr/local/include/* /final/usr/local/include/
cp -rp /usr/local/lib/* /final/usr/local/lib/
cp -rp /usr/local/sbin/* /final/usr/local/sbin/
cp -rp /usr/local/share/* /final/usr/local/share/ 
cp -rp /usr/share/postgresql/* /final/usr/share/postgresql/
cp -rp /usr/lib/postgresql/* /final/usr/lib/postgresql/ 

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