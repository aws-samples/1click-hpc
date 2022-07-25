#!/bin/bash
set -e

installCustom{
    amazon-linux-extras enable python3.8
    yum install -y python38 python38-devel tmux htop glances aria2 transmission-cli pssh
}

# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 00.install.custom.packages.headnode.sh: START" >&2
    installCustom
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 00.install.custom.packages.headnode.sh: STOP" >&2
}

main "$@"