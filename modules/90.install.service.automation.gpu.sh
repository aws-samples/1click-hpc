#!/bin/bash
set -x
set -e

# this script will create credentials file for mysql client to upload the test results (see prolog_smippet.sh)

# service database must exist. credentials must be stored in AWS Secrets before deploying

configMySQLcredentials(){

    # install some python libs
    yum -y install mysql
    python3.8 -m pip install mysql-connector-python botocore aws-secretsmanager-caching

    creds=$(aws secretsmanager get-secret-value --secret-id serviceDBcred --region us-east-1 | jq -r '.SecretString')
    export host=$(jq -r '.host' <<< "$creds")
    export user=$(jq -r '.username' <<< "$creds")
    export password=$(jq -r '.password' <<< "$creds")

    cat <<'EOF' > /root/my.cnf
[client]
host     = ${host}
user     = ${user}
password = ${password}
socket   = /var/run/mysqld/mysqld.sock
database = service
EOF

    /usr/bin/envsubst < "/root/my.cnf" > /root/.my.cnf

    chmod 600 /root/.my.cnf
    rm -f /root/my.cnf
}

# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 90.install.service.automation.gpu.sh: START" >&2
    configMySQLcredentials
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 90.install.service.automation.gpu.sh: STOP" >&2
}

main "$@"