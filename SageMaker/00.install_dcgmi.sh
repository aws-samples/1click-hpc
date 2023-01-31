#!/bin/bash
TEMP_DIR=/tmp/dcgmi
rm -rf ${TEMP_DIR}
mkdir -p ${TEMP_DIR}
pushd ${TEMP_DIR}
curl -s wget  https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/3bf863cc.pub |apt-key add - &&  \
apt-add-repository  "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/ / " && apt-get -q -o DPkg::Lock::Timeout=240 update && apt-get  -q -o DPkg::Lock::Timeout=240 install -y datacenter-gpu-manager

#run dcgm-exporter after reboot - moved to /admin/hosts/crontab
#line="@reboot docker run -d --gpus all --rm -p 9400:9400 nvcr.io/nvidia/k8s/dcgm-exporter:3.1.3-3.1.2-ubuntu20.04"
#(crontab -u $(whoami) -l; echo "$line" ) | crontab -u $(whoami) -

docker run -d --gpus all --rm -p 9400:9400 nvcr.io/nvidia/k8s/dcgm-exporter:3.1.3-3.1.2-ubuntu20.04
