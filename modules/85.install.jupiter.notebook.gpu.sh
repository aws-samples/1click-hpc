#!/bin/bash
set -x
set -e

installJypyter() {
    python3 -m pip install notebook
}


# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 85.install.jupiter.notebook.gpu.sh: START" >&2
    installJypyter
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 85.install.jupiter.notebook.gpu.sh: STOP" >&2
}

main "$@"