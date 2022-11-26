#!/bin/bash
set -x
set -e

boostClock() {
    wget -O /tmp/aws-gpu-boost-clock.sh 'https://github.com/aws-samples/aws-efa-nccl-baseami-pipeline/raw/master/nvidia-efa-ami_base/boost/aws-gpu-boost-clock.sh'
    wget -O /tmp/aws-gpu-boost-clock.service 'https://github.com/aws-samples/aws-efa-nccl-baseami-pipeline/raw/master/nvidia-efa-ami_base/boost/aws-gpu-boost-clock.service'
    mv /tmp/aws-gpu-boost-clock.sh /opt/aws/ && chmod +x /opt/aws/aws-gpu-boost-clock.sh
    mv /tmp/aws-gpu-boost-clock.service /lib/systemd/system
    systemctl enable aws-gpu-boost-clock.service && systemctl start aws-gpu-boost-clock.service
}


# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 35.boost.gpu.clock.gpu.sh: START" >&2
    boostClock
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 35.boost.gpu.clock.gpu.sh: STOP" >&2
}

main "$@"