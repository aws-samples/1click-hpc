#!/bin/bash
set -x
set -e

installCustom() {
    apt -y update && apt -y upgrade
    apt install -y tmux htop iftop transmission-cli pssh python3.8-venv rustc cargo git-lfs
    add-apt-repository -y ppa:deadsnakes/ppa
    apt-get -y update
    apt-get -y install python3.11 python3.11-venv python3.11-dev python3.11-distutils
    #rm /usr/bin/python3
    #ln -s /usr/bin/python3.8 /usr/bin/python3
    pip3 install glances
    apt -y remove postgres*
}

# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 00.install.custom.packages.headnode.sh: START" >&2
    installCustom
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 00.install.custom.packages.headnode.sh: STOP" >&2
}

main "$@"