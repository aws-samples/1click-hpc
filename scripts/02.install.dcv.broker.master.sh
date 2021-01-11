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


# Installs DCV Session Broker on master host

source '/etc/parallelcluster/cfnconfig'

export NICE_ROOT="${cfn_shared_dir}/nice"
NICE_GPG_KEY_URL="https://d1uj6qtbmh3dt5.cloudfront.net/NICE-GPG-KEY"

set -x
set -e

# install DCV Session Broker
installDCVSessionBroker() {
    # get the DCV-SM rpm from the official repository
    wget -P /tmp/packages https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-session-manager-broker.el7.noarch.rpm || exit 1
    
    # set permissions and uncompress
    chmod 755 -R /tmp/packages/*
    dcv_session_broker_pkg=$(find /tmp/packages -type f -name 'nice-dcv-session-manager-broker.*.rpm')
    # some checks
    [[ -z ${dcv_session_broker_pkg} ]] && \
        echo "[ERROR] missing DCV Session Broker rpm" && return 1

    rpm --import "${NICE_GPG_KEY_URL}"
    yum install -y "${dcv_session_broker_pkg}"
    # switch broker to 8446 since 8443 is used by EnginFrame
    sed -i 's/client-to-broker-connector-https-port = .*$/client-to-broker-connector-https-port = 8446/' \
        /etc/dcv-session-manager-broker/session-manager-broker.properties
    # switch broker discovery port to 45001 since in the boot phase it can be busy
    #sed -i 's/broker-to-broker-discovery-port = .*$/broker-to-broker-discovery-port = 47501/' \
    #    /etc/dcv-session-manager-broker/session-manager-broker.properties
    #sed -i 's/broker-to-broker-discovery-addresses = .*$/broker-to-broker-discovery-addresses = 127.0.0.1:47501/' \
    #    /etc/dcv-session-manager-broker/session-manager-broker.properties
}


# start DCV session broker
startDCVSessionBroker() {
    local -i attempts=10 wait=1
    systemctl enable dcv-session-manager-broker
    systemctl start dcv-session-manager-broker
    sleep 10    # wait for a correct ignite initialization
    efadmin_home=$(getent passwd | grep efadmin | sed 's/^.*:.*:.*:.*:.*:\(.*\):.*$/\1/')

    # wait for the certificate to be available, and copy it to efadmin's home
    while [[ $((attempts--)) -gt 0 ]]; do
        if [[ -r /var/lib/dcvsmbroker/security/dcvsmbroker_ca.pem ]]; then
            cp /var/lib/dcvsmbroker/security/dcvsmbroker_ca.pem "${efadmin_home}"
            break
        else sleep $((wait++))
        fi
    done
    [[ ${attempts} -gt 0 ]] || return 1
}


# sets DCV session broker in EnginFrame
# avoid this function if you don't install EnginFrame
setupEFSessionManager() {
    local -i attempts=10 wait=1
    source "${NICE_ROOT}/enginframe/conf/enginframe.conf"

    # register and set EnginFrame as API client
    while [[ $((attempts--)) -gt 0 ]]; do
        systemctl is-active --quiet dcv-session-manager-broker
        if [[ $? == 0 ]]; then
            dcv-session-manager-broker register-api-client --client-name EnginFrame > /tmp/packages/ef_client_reg
            [[ $? == 0 ]] || return 1
            break
        else sleep $((wait++))
        fi
    done
    [[ ${attempts} -gt 0 ]] || return 1

    client_id=$(cat /tmp/packages/ef_client_reg | sed -n 's/^[ \t]*client-id:[ \t]*//p')
    client_pw=$(cat /tmp/packages/ef_client_reg | sed -n 's/^[ \t]*client-password:[ \t]*//p')
    sed -i "s/^DCVSM_CLUSTER_dcvsm_cluster1_AUTH_ID=.*$/DCVSM_CLUSTER_dcvsm_cluster1_AUTH_ID=${client_id//\//\\/}/" \
        /shared/nice/enginframe/conf/plugins/dcvsm/clusters.props
    sed -i \
        "s/^DCVSM_CLUSTER_dcvsm_cluster1_AUTH_PASSWORD=.*$/DCVSM_CLUSTER_dcvsm_cluster1_AUTH_PASSWORD=${client_pw//\//\\/}/" \
        /shared/nice/enginframe/conf/plugins/dcvsm/clusters.props
    sed -i \
        "s/^DCVSM_CLUSTER_dcvsm_cluster1_AUTH_ENDPOINT=.*$/DCVSM_CLUSTER_dcvsm_cluster1_AUTH_ENDPOINT=https:\/\/$(hostname):8446\/oauth2\/token/" \
        /shared/nice/enginframe/conf/plugins/dcvsm/clusters.props
    sed -i \
        "s/^DCVSM_CLUSTER_dcvsm_cluster1_SESSION_MANAGER_ENDPOINT=.*$/DCVSM_CLUSTER_dcvsm_cluster1_SESSION_MANAGER_ENDPOINT=https:\/\/$(hostname):8446/" \
        /shared/nice/enginframe/conf/plugins/dcvsm/clusters.props

    # add dcvsm certificate to Java keystore
    openssl x509 -in /var/lib/dcvsmbroker/security/dcvsmbroker_ca.pem -inform pem \
        -out /tmp/packages/dcvsmbroker_ca.der -outform der
    keytool -importcert -alias dcvsm \
            -keystore "${JAVA_HOME}/lib/security/cacerts" \
            -storepass changeit \
            -noprompt \
            -file /tmp/packages/dcvsmbroker_ca.der
    systemctl restart enginframe
}


# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] install.dcv.broker.master.sh: START" >&2

    installDCVSessionBroker
    startDCVSessionBroker
    setupEFSessionManager

    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] install.dcv.broker.master.sh: STOP" >&2
}

main "$@"