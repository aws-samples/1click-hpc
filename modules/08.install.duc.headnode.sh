#!/bin/bash
set -x
set -e

installCustom() {
    wget https://github.com/zevv/duc/releases/download/1.4.5/duc-1.4.5.tar.gz
    tar -xzvf duc-1.4.5.tar.gz
    cd duc-1.4.5
    ./configure
    make
    sudo make install
}

# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 08.install.duc.headnode.sh: START" >&2
    installCustom
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 08.install.duc.headnode.sh: STOP" >&2
}

main "$@"