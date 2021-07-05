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

export DCV_SM_ROOT="/etc/dcv-session-manager-agent"
export NICE_ROOT=$(jq --arg default "${SHARED_FS_DIR}/nice" -r '.post_install.enginframe | if has("nice_root") then .nice_root else $default end' "${dna_json}")
export CLIENT_BROKER_PORT=$(jq --arg default "8446" -r '.post_install.dcvsm | if has("client_broker_port") then .client_broker_port else $default end' "${dna_json}")
export AGENT_BROKER_PORT=$(jq --arg default "8445" -r '.post_install.dcvsm | if has("agent_broker_port") then .agent_broker_port else $default end' "${dna_json}")
export BROKER_CA=$(jq --arg default "${ec2user_home}/dcvsmbroker_ca.pem" -r '.post_install.dcvsm | if has("broker_ca") then .broker_ca else $default end' "${dna_json}")
export DCV_KEY_WORD=$(jq --arg default "dcv" -r '.post_install.dcv | if has("dcv_queue_keyword") then .dcv_queue_keyword else $default end' "${dna_json}")
export SLURM_CONF_FILE="/opt/slurm/etc/pcluster/slurm_parallelcluster_*_partition.conf"
export BROKER_CA_NEW="${DCV_SM_ROOT}/dcvsmbroker_ca.pem"
export DCV_SM_AGENT_CONF="${DCV_SM_ROOT}/agent.conf"

master_hostname=$(cat /etc/parallelcluster/slurm_plugin/master_private_ip)
#Slurm indipendent
#master_hostname=$(cat /etc/fstab | grep "[0-9\.]*${cfn_shared_dir}" | sed 's/^\([0-9\.]*\).*/\1/')

set -x
set -e

configureDCVforSMAgent() {
    
    pattern='\[security\]'
    replace='&\n'
    replace+='administrators=["dcvsmagent"]\n'
    replace+='ca-file="/etc/dcv-session-manager-agent/dcvsmbroker_ca.pem"\n'
    replace+="auth-token-verifier=\"https://${master_hostname}:${AGENT_BROKER_PORT}/agent/validate-authentication-token\""
    cp '/etc/dcv/dcv.conf' "/etc/dcv/dcv.conf.$(date --iso=s --utc)"
    # remove duplicates if any
    #sed -i -e '/^ *\(administrators\|ca-file\|auth-token-verifier\) *=.*$/d' '/etc/dcv/dcv.conf'
    sed -i -e "s|${pattern}|${replace}|" '/etc/dcv/dcv.conf'

}

installDCVSMAgent() {
    
    rpm --import "${NICE_GPG_KEY_URL}"
    yum -y install https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-session-manager-agent.el7.x86_64.rpm || exit 1

    pattern='^ *broker_host *=.*$'
    replace="broker_host = \'${master_hostname}\'"
    sed -i -e "s|${pattern}|${replace}|" "${DCV_SM_AGENT_CONF}"

    pattern='^ *#broker_port *=.*$'
    replace="broker_port = ${AGENT_BROKER_PORT}"
    sed -i -e "s|${pattern}|${replace}|" "${DCV_SM_AGENT_CONF}"

    pattern='^ *#ca_file *=.*$'
    replace="ca_file = \'${BROKER_CA_NEW}\'"
    sed -i -e "s|${pattern}|${replace}|" "${DCV_SM_AGENT_CONF}"
    cp "${BROKER_CA}" "${BROKER_CA_NEW}"
    
}


configureAgentTags() {
    mkdir -p "${DCV_SM_ROOT}/tags"
    echo "AWS_EC2_PUBLIC_HOSTNAME=\"$(ec2-metadata -p| awk '{print $2}')\"" >> "${DCV_SM_ROOT}/tags/agent_tags.toml"
    echo "INSTANCE_TYPE=\"$(ec2-metadata -t| awk '{print $2}')\"" >> "${DCV_SM_ROOT}/tags/agent_tags.toml"
    echo "AWS_EC2_INSTANCE_ID=\"$(ec2-metadata -i| awk '{print $2}')\"" >> "${DCV_SM_ROOT}/tags/agent_tags.toml"
}

startServices() {
    
    systemctl start dcv-session-manager-agent
    systemctl restart dcvserver.service

}

# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] install.dcv-sm-agent.compute.sh: START" >&2
    
    for conf_file in $(ls ${SLURM_CONF_FILE} | grep "${DCV_KEY_WORD}"); do
        if [[ ! -z $(grep "${compute_instance_type}" "${conf_file}") ]]; then
            configureDCVforSMAgent
            installDCVSMAgent
            configureAgentTags
            startServices
        fi
    done
    
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] install.dcv-sm-agent.compute.sh: STOP" >&2
}

main "$@"