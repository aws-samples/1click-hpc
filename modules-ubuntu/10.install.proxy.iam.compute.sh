#!/bin/bash

set -x
set -e

installCustom() {
    git clone https://github.com/Stability-AI/iam-credentials-api-proxy /opt/iam-credentials-api-proxy
    cp /opt/iam-credentials-api-proxy/ica.service /etc/systemd/system/ica.service
    #change IamApiDev-EndpointHostSecret with your secret name where you store the IamApi EndpointHost #todo: do not hardcode, add secret name as CF parameter
    icahost=$(aws secretsmanager get-secret-value --secret-id IamApiprod-EndpointHostSecret --query SecretString --output text --region us-west-2 --cli-connect-timeout 1)
    sed -i "s|target_hostname|$icahost|g" /etc/systemd/system/ica.service
    systemctl daemon-reload
    systemctl enable ica.service
    systemctl start ica.service
    ln -s /opt/slurm/sbin/stablessh /usr/local/bin/stablessh
    #restrict ssh access only to Sudoers group
    #echo "AllowGroups Sudoers" >> /etc/ssh/sshd_config
    systemctl restart sshd
}


# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 10.install.proxy.iam.compute.sh: START" >&2
    installCustom
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 10.install.proxy.iam.compute.sh: STOP" >&2
}

main "$@"