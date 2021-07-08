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

#temporary fix to manually disable Anacron, up until PC handles this.
disableAnacron() {
    sed 's/^/#/' /etc/anacrontab > /etc/anacrontab.tmp
    mv -f --backup /etc/anacrontab.tmp /etc/anacrontab
}

#temporary fix to manually downgrade CloudWatch: https://github.com/aws/aws-parallelcluster/wiki/Possible-performance-degradation-on-ALinux2-when-using-ParallelCluster-2.11.0-and-custom-AMIs-from-2.6.0-to-2.11.0
downgradeCW(){
    systemctl stop amazon-cloudwatch-agent.service
    yum -y downgrade amazon-cloudwatch-agent-1.247347.4-1.amzn2
    systemctl start amazon-cloudwatch-agent.service
    
}

# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 04.configure.disable.anacron.compute.sh: START" >&2
    disableAnacron
    downgradeCW
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 04.configure.disable.anacron.compute.sh: STOP" >&2
}

main "$@"