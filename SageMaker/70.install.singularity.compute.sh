#!/bin/bash
set -x
set -e

installSingularity() {
    TMP_DIR="/tmp/singularity"
    mkdir -p ${TMP_DIR}
    pushd ${TMP_DIR}
    # Install deb packages for dependencies
    sudo apt install -y libseccomp-dev libglib2.0-dev squashfs-tools cryptsetup runc
    wget https://go.dev/dl/go1.18.3.linux-amd64.tar.gz
    sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.18.3.linux-amd64.tar.gz
    sudo bash -c "echo 'export PATH=/usr/local/go/bin:$PATH' >> /etc/profile.d/singularity.sh"
    wget https://github.com/sylabs/singularity/releases/download/v3.10.0/singularity-ce_3.10.0-focal_amd64.deb
    sudo dpkg -i singularity-ce_3.10.0-focal_amd64.deb
    popd
    rm -rf ${TMP_DIR}
}


# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 70.install.singularity.compute.sh: START" >&2
    installSingularity
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 70.install.singularity.compute.sh: STOP" >&2
}

main "$@"
