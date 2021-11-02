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



set -x
set -e

installPreReq() {
    yum -y -q install docker golang-bin 
    service docker start
    chkconfig docker on
    usermod -a -G docker $cfn_cluster_user

    #to be replaced with yum -y install docker-compose as the repository problem is fixed
    curl -s -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
}

installMonitoring() {
    
    gpu_instances="[pg][2-9].*\.[0-9]*[x]*large"

    if [[ $compute_instance_type =~ $gpu_instances ]]; then
		distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
		curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.repo | tee /etc/yum.repos.d/nvidia-docker.repo
		yum -y -q clean expire-cache
		yum -y -q install nvidia-docker2
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
   
    job_id=$($SLURM_ROOT/bin/squeue -h -w "${host_name}" | awk '{print $1}')
    job_comment=$($SLURM_ROOT/bin/scontrol show job $job_id | grep Comment  | sed 's/Comment=//' | sed 's/^ *//g')
    
    if [[ $job_comment == *"Key=Monitoring,Value=ON"* ]]; then
        installPreReq
        installMonitoring
    fi
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 40.install.monitoring.compute.sh: STOP" >&2
}
main "$@"