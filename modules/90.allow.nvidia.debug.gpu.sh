#!/bin/bash
set -x
set -e

allowDebugGPU() {
    aws s3 cp --quiet "${post_install_base}/nvidia/99-nvidia-debug" /etc/sudoers.d/ --region "${cfn_region}" || exit 1
}

installDCGM {
    yum-config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/cuda-rhel7.repo
    yum clean all
    yum install -y datacenter-gpu-manager
    # Start nv-hostengine
    sudo -u root nv-hostengine -b 0
}


# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 90.allow.nvidia.debug.gpu.sh: START" >&2
    allowDebugGPU
    installDCGM
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 90.allow.nvidia.debug.gpu.sh: STOP" >&2
}

main "$@"