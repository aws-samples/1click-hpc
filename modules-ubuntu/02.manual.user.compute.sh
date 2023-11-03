#!/bin/bash

set -x

source "/etc/parallelcluster/cfnconfig"

function addusers() {
    IFS=","

    if [ "${cfn_node_type}" = "ComputeFleet" ]; then
        while read USERNAME USERID
        do
            # -M do not create home since head node is exporting /homes via NFS
            # -u to set UID to match what is set on the head node
            if ! [ $(id -u $USERNAME 2>/dev/null || echo -1) -ge 0 ]; then
                useradd -M -u $USERID $USERNAME
            fi
        done < "/admin/userlistfile"
    fi
}


# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 02.manual.users.compute.sh: START" >&2
    addusers
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 02.manual.users.compute.sh: STOP" >&2
}

main "$@"