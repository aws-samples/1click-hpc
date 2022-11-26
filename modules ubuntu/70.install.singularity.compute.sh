#!/bin/bash
set -x 
set -e 

installSingularity() {

    # Install RPM packages for dependencies
    yum install -y libseccomp-devel glib2-devel squashfs-tools cryptsetup runc
    wget https://go.dev/dl/go1.18.3.linux-amd64.tar.gz
    rm -rf /usr/local/go && tar -C /usr/local -xzf go1.18.3.linux-amd64.tar.gz
    echo 'export PATH=/usr/local/go/bin:$PATH' >> /etc/profile.d/singularity.sh

    wget https://github.com/sylabs/singularity/releases/download/v3.10.0/singularity-ce-3.10.0-1.el7.x86_64.rpm
    rpm -i singularity-ce-3.10.0-1.el7.x86_64.rpm
}


# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 70.install.singularity.compute.sh: START" >&2
    installSingularity
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 70.install.singularity.compute.sh: STOP" >&2
}

main "$@"