#!/bin/bash
set -e

allowDebugGPU {
    aws s3 cp --quiet "${post_install_base}/nvidia/99-nvidia-debug" /etc/sudoers.d/ --region "${cfn_region}" || exit 1
}


# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 90.allow.nvidia.debug.gpu.sh: START" >&2
    allowDebugGPU
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 90.allow.nvidia.debug.gpu.sh: STOP" >&2
}

main "$@"