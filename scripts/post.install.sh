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
export efadminPassword="$2"
myscripts="${@:3}"

source '/etc/parallelcluster/cfnconfig'

export post_install_url=$(dirname ${cfn_postinstall})
proto="$(echo $post_install_url | grep :// | sed -e's,^\(.*://\).*,\1,g')"

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
            aws s3 sync s3://${post_install_url}/${script} /tmp/scripts || exit 1
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


# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] post.install.sh START" >&2
    runScripts
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] post.install.sh: STOP" >&2
}

main "$@"