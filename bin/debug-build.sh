mkdir /build.d
build.rc /
cp /mnt/package-list-build /
cp /mnt/build.d/build-prereqs.sh /build.d/
bash /build.d/build-prereqs.sh
cp /mnt/build.d/update-certs.sh /build.d/
bash /build.d/update-certs.sh
cp /mnt/build.d/gvm-libs.sh /build.d/
bash /build.d/gvm-libs.sh
cp /mnt/build.d/openvas-smb.sh /build.d/
bash /build.d/openvas-smb.sh
cp /mnt/build.d/gvmd.sh /build.d/
bash /build.d/gvmd.sh
cp /mnt/build.d/openvas-scanner.sh /build.d/
bash /build.d/openvas-scanner.sh
cp /mnt/build.d/gsa.sh /build.d/
bash /build.d/gsa.sh
cp /mnt/build.d/ospd.sh /build.d/
bash /build.d/ospd.sh
cp /mnt/build.d/ospd-openvas.sh /build.d/
bash /build.d/ospd-openvas.sh
cp /mnt/build.d/gvm-tool.sh /build.d/
bash /build.d/gvm-tool.sh
cp /mnt/build.d/links.sh /build.d/
bash /build.d/links.sh

