#!/bin/bash
set -x
set -e

installCustom() {
    amazon-linux-extras enable python3.8
    yum install wget tmux python38 htop hwloc iftop aria2 kernel-tools numactl python3-devel python38-devel kernel-devel check check-devel subunit subunit-devel -y
    yum groupinstall -y 'Development Tools'
    pip3 install glances
}


# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 00.install.custom.packages.compute.sh: START" >&2
    installCustom
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 00.install.custom.packages.compute.sh: STOP" >&2
}

main "$@"