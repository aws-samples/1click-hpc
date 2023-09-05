#!/bin/bash

set -x
set -e


installCustom() {
    git clone https://github.com/Stability-AI/iam-credentials-api-proxy /root/iam-credentials-api-proxy
    cp /root/iam-credentials-api-proxy/ica.service /etc/systemd/system/ica.service
    icahost=$(aws secretsmanager get-secret-value --secret-id "ICAproxyHostname" --query SecretString --output text --region "us-west-2")
    sed -i "s|target_hostname|$icahost|g" /etc/systemd/system/ica.service
    systemctl daemon-reload
    systemctl enable ica.service
    systemctl start ica.service
}


# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 08.install.duc.headnode.sh: START" >&2
    installCustom
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 08.install.duc.headnode.sh: STOP" >&2
}

main "$@"