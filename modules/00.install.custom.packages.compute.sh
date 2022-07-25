#!/bin/bash
set -e

installCustom{
    amazon-linux-extras enable python3.8
    yum install wget tmux python38 glances htop hwloc iftop kernel-tools numactl python3-devel python38-devel kernel-devel check check-devel subunit subunit-devel -y
    yum groupinstall -y 'Development Tools'
}


# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 00.install.custom.packages.compute.sh: START" >&2
    installCustom
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 00.install.custom.packages.compute.sh: STOP" >&2
}

main "$@"