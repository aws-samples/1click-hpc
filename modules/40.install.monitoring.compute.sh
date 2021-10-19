#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this
# software and associated documentation files (the "Software"), to deal in the Software
# without restriction, including without limitation the rights to use, copy, modify,
# merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
# PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

source /etc/parallelcluster/cfnconfig
compute_instance_type=$(ec2-metadata -t | awk '{print $2}')
gpu_instances="[pg][2-9].*\.[0-9]*[x]*large"

monitoring_dir_name="monitoring"
monitoring_home="${SHARED_FS_DIR}/${monitoring_dir_name}"

set -x
set -e

installPreReq() {
    yum -y install docker golang-bin 
    service docker start
    chkconfig docker on
    usermod -a -G docker $cfn_cluster_user

    #to be replaced with yum -y install docker-compose as the repository problem is fixed
    curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
}

configureMonitoring() {
    if [[ $compute_instance_type =~ $gpu_instances ]]; then
		distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
		curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.repo | tee /etc/yum.repos.d/nvidia-docker.repo
		yum -y clean expire-cache
		yum -y install nvidia-docker2
		systemctl restart docker
		/usr/local/bin/docker-compose -f "${monitoring_home}/docker-compose/docker-compose.compute.gpu.yml" -p monitoring-compute up -d
    else
		/usr/local/bin/docker-compose -f "${monitoring_home}/docker-compose/docker-compose.compute.yml" -p monitoring-compute up -d
    fi
}

# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 40.install.monitoring.compute.sh: START" >&2
    
    instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    monitoring=$(aws ec2 describe-tags  --region us-east-2 --filters "Name=resource-id,Values=${instance_id}" "Name=key,Values=Monitoring" | jq -r '.Tags[].Value')
    
    if [[ $monitoring = "ON" ]]; then
        installPreReq
        configureMonitoring
    fi
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 40.install.monitoring.compute.sh: STOP" >&2
}
main "$@"