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


# Top level post install script

# get post install arguments
export S3Bucket="$2"
export S3Key="$3"
export efadminPassword="$4"

source '/etc/parallelcluster/cfnconfig'


# run scripts
# ----------------------------------------------------------------------------
# runs secondary scripts according to the node type
runScripts() {
    # get packages from S3
    echo "Getting S3 packages from ${S3Bucket}"
    aws s3 sync s3://${S3Bucket}/${S3Key}/scripts /tmp/scripts || exit 1
    chmod 755 -R /tmp/scripts/*
    # run scripts according to node type
    if [[ ${cfn_node_type} == MasterServer ]]; then
        find /tmp/scripts -type f -name '[0-9][0-9]*.master.sh' -print0 | \
            sort -z -n | xargs -0 -I '{}' /bin/bash -c '{}'
    fi
    if [[ ${cfn_node_type} == ComputeFleet ]]; then

        find /tmp/scripts -type f -name '[0-9][0-9]*.compute.sh' -print0 | \
            sort -z -n | xargs -0 -I '{}' /bin/bash -c '{}'
    fi
}


# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] post.install.sh START" >&2
    runScripts
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] post.install.sh: STOP" >&2
}

main "$@"
