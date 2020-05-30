export LANG="C.UTF-8"


bash ./install-pkgs.sh

gvm_libs_version="v11.0.1" \
openvas_scanner_version="v7.0.1" \
gvmd_version="v9.0.1" \
gsa_version="v9.0.1" \
gvm_tools_version="v2.1.0" \
openvas_smb="v1.0.5" \
open_scanner_protocol_daemon="v2.0.1" \
ospd_openvas="v1.0.1" \
python_gvm_version="v1.5.0"

echo "Starting Build..." && mkdir /build

    #
    # install libraries module for the Greenbone Vulnerability Management Solution
    #
mkdir /build 
cd /build && \
    wget --no-verbose https://github.com/greenbone/gvm-libs/archive/$gvm_libs_version.tar.gz && \
    tar -zxf $gvm_libs_version.tar.gz && \
    cd /build/*/ && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release .. && \
    make && \
    make install && \
    cd /build && \
    rm -rf *

    #
    # install smb module for the OpenVAS Scanner
    #
    
cd /build && \
    wget --no-verbose https://github.com/greenbone/openvas-smb/archive/$openvas_smb.tar.gz && \
    tar -zxf $openvas_smb.tar.gz && \
    cd /build/*/ && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release .. && \
    make && \
    make install && \
    cd /build && \
    rm -rf *
    
    #
    # Install Greenbone Vulnerability Manager (GVMD)
    #
    
cd /build && \
    wget --no-verbose https://github.com/greenbone/gvmd/archive/$gvmd_version.tar.gz && \
    tar -zxf $gvmd_version.tar.gz && \
    cd /build/*/ && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release .. && \
    make && \
    make install && \
    cd /build && \
    rm -rf *
    
    #
    # Install Open Vulnerability Assessment System (OpenVAS) Scanner of the Greenbone Vulnerability Management (GVM) Solution
    #
    
cd /build && \
    wget --no-verbose https://github.com/greenbone/openvas-scanner/archive/$openvas_scanner_version.tar.gz && \
    tar -zxf $openvas_scanner_version.tar.gz && \
    cd /build/*/ && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release .. && \
    make && \
    make install && \
    cd /build && \
    rm -rf *
    
    #
    # Install Greenbone Security Assistant (GSA)
    #
   
cd /build && \
    wget --no-verbose https://github.com/greenbone/gsa/archive/$gsa_version.tar.gz && \
    tar -zxf $gsa_version.tar.gz && \
    cd /build/*/ && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release .. && \
    make && \
    make install && \
    cd /build && \
    rm -rf *
    
    #
    # Install Greenbone Vulnerability Management Python Library
    #
    
cd /build && \
    wget --no-verbose https://github.com/greenbone/python-gvm/archive/$python_gvm_version.tar.gz && \
    tar -zxf $python_gvm_version.tar.gz && \
    cd /build/*/ && \
    python3 setup.py install && \
    cd /build && \
    rm -rf *
    
    #
    # Install Open Scanner Protocol daemon (OSPd)
    #
    
cd /build && \
    wget --no-verbose https://github.com/greenbone/ospd/archive/$open_scanner_protocol_daemon.tar.gz && \
    tar -zxf $open_scanner_protocol_daemon.tar.gz && \
    cd /build/*/ && \
    python3 setup.py install && \
    cd /build && \
    rm -rf *
    
    #
    # Install Open Scanner Protocol for OpenVAS
    #
    
cd /build && \
    wget --no-verbose https://github.com/greenbone/ospd-openvas/archive/$ospd_openvas.tar.gz && \
    tar -zxf $ospd_openvas.tar.gz && \
    cd /build/*/ && \
    python3 setup.py install && \
    cd /build && \
    rm -rf *
    
    #
    # Install GVM-Tools
    #
    
cd /build && \
    wget --no-verbose https://github.com/greenbone/gvm-tools/archive/$gvm_tools_version.tar.gz && \
    tar -zxf $gvm_tools_version.tar.gz && \
    cd /build/*/ && \
    python3 setup.py install && \
    echo "/usr/local/lib" > /etc/ld.so.conf.d/openvas.conf && ldconfig && cd / && rm -rf /build

