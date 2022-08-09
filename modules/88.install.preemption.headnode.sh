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


#max_queue_size=$(aws cloudformation describe-stacks --stack-name $stack_name --region $cfn_region | jq -r '.Stacks[0].Parameters | map(select(.ParameterKey == "MaxSize"))[0].ParameterValue')

set -x
set -e

installPreemptionQos() {
    echo " " >> /opt/slurm/etc/slurm.conf
    echo "# PREEMPTION" >> /opt/slurm/etc/slurm.conf
    echo "PreemptMode=Requeue" >> /opt/slurm/etc/slurm.conf
    echo "PreemptType=preempt/qos" >> /opt/slurm/etc/slurm.conf
    echo "PriorityType=priority/multifactor" >> /opt/slurm/etc/slurm.conf
}



# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 88.install.preemption.headnode.sh: START" >&2
    installPreemptionQos
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 88.install.preemption.headnode.sh: STOP" >&2
}

main "$@"