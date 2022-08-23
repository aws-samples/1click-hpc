#!/bin/bash
set -x
set -e

installCustom() {
    amazon-linux-extras install epel -y
    yum install -y knot-resolver knot-utils
    sh -c 'echo nameserver 127.0.0.1 > /etc/resolv.conf'
    systemctl enable --now kresd@{1..4}.service
}


# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 00.install.knot.resolver.cpu.sh: START" >&2
    installCustom
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 00.install.knot.resolver.cpu.sh: STOP" >&2
}

main "$@"