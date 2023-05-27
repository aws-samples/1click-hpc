#!/bin/bash
set -x
set -e

installCustom() {
    apt-get -y update && apt-get -y upgrade
    apt-get -y install wget tmux htop hwloc iftop aria2 numactl check subunit
    pip3 install glances
    apt-get -y remove postgres*
}

# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 00.install.custom.packages.compute.sh: START" >&2
    installCustom
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 00.install.custom.packages.compute.sh: STOP" >&2
}

main "$@"
