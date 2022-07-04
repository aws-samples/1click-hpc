#!/bin/bash
# Install basic tools for compiling

# Install RPM packages for dependencies
yum install -y libseccomp-devel glib2-devel squashfs-tools cryptsetup runc
wget https://go.dev/dl/go1.18.3.linux-amd64.tar.gz
rm -rf /usr/local/go && tar -C /usr/local -xzf go1.18.3.linux-amd64.tar.gz
echo 'export PATH=/usr/local/go/bin:$PATH' >> /etc/profile.d/singularity.sh

wget https://github.com/sylabs/singularity/releases/download/v3.10.0/singularity-ce-3.10.0-1.el7.x86_64.rpm
rpm -i singularity-ce-3.10.0-1.el7.x86_64.rpm
