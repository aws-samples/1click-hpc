#!/bin/bash
set -x
set -e

installCustom() {
    apt-get -y update && apt-get -y upgrade
    apt-get -y install wget tmux htop hwloc iftop aria2 numactl check subunit python3.8-venv rustc cargo 
    add-apt-repository -y ppa:deadsnakes/ppa
    apt-get -y update
    apt-get -y install python3.11 python3.11-venv python3.11-dev python3.11-distutils
    #rm /usr/bin/python3
    #ln -s /usr/bin/python3.8 /usr/bin/python3
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
