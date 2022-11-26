#!/bin/bash
set -x
set -e

installCustom() {
    apt -y update && apt -y upgrade
    apt install -y tmux htop iftop transmission-cli pssh
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