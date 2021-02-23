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

source '/etc/parallelcluster/cfnconfig'

# run scripts
# ----------------------------------------------------------------------------
# runs secondary scripts according to the node type
runScripts() {
    
    # get packages from Git-Hub
    echo "Getting packages from ${post_install_url}"
    for script in ${myscripts}; do
        if [[ ${proto} == "https://" ]]; then
            wget -P /tmp/scripts "${post_install_url}/${script}" || exit 1 
        elif [[ ${proto} == "s3://" ]]; then
            aws s3 cp ${post_install_url}/${script} /tmp/scripts/ || exit 1
        else
            exit 1
        fi
    done

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

findSharedDir() {
    fsx=$(mount | grep lustre | awk '{print $3}')
    if [[ -z "$fsx" ]]; then
        echo "$cfn_shared_dir" | awk -F , '{print $1}'
    else
        echo "$fsx"
    fi
}


# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] post.install.sh START" >&2
    runScripts
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] post.install.sh: STOP" >&2
}

export NICE_GPG_KEY_URL=${NICE_GPG_KEY_URL:-"https://d1uj6qtbmh3dt5.cloudfront.net/NICE-GPG-KEY"}

export post_install_url=$(dirname ${cfn_postinstall})
export post_install_base=$(dirname "${post_install_url}")
export proto="$(echo $post_install_url | grep :// | sed -e's,^\(.*://\).*,\1,g')"

export compute_instance_type=$(ec2-metadata -t | awk '{print $2}')
export SHARED_FS_DIR=$(findSharedDir)

# get post install arguments
export ec2user_home=$(getent passwd | grep ec2-user | sed 's/^.*:.*:.*:.*:.*:\(.*\):.*$/\1/')
export dna_json="/etc/chef/dna.json"
export myscripts="${@:2}"

main "$@"