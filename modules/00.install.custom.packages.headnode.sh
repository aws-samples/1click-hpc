#!/bin/bash
set -x
set -e

installCustom() {
    amazon-linux-extras enable python3.8

    #yum -y update
    yum install -y python38 python38-devel tmux htop iftop transmission-cli pssh pango-devel cairo-devel tokyocabinet-devel
    pip3 install glances
}

# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 00.install.custom.packages.headnode.sh: START" >&2
    installCustom
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 00.install.custom.packages.headnode.sh: STOP" >&2
}

main "$@"