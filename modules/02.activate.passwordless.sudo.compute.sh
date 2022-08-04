#!/bin/bash
set -x
set -e

addAdmins2Sudoers() {
    cat > /etc/sudoers.d/100-AD-admins << EOF
# add domain admins as sudoers
%Sudoers  ALL=(ALL) NOPASSWD:ALL
EOF
}


# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 02.activate.passwordless.sudo.compute.sh: START" >&2
    addAdmins2Sudoers
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 02.activate.passwordless.sudo.compute.sh: STOP" >&2
}

main "$@"



