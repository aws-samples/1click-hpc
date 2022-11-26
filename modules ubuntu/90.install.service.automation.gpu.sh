#!/bin/bash
set -x
set -e

# this script will create credentials file for mysql client to upload the test results (see prolog_smippet.sh)

# service database must exist. credentials must be stored in AWS Secrets before deploying

configMySQLcredentials(){

    # install some python libs
    # yum -y install mysql # dependencies errors in AL2 repo 2022-11-11
    cat <<'EOF' > /etc/yum.repos.d/MariaDB.repo
# MariaDB 10.6 CentOS repository list - created 2021-10-31 17:42 UTC
# https://mariadb.org/download/
[mariadb]
name = MariaDB
baseurl = http://nyc2.mirrors.digitalocean.com/mariadb/yum/10.6/centos7-amd64
gpgkey=http://nyc2.mirrors.digitalocean.com/mariadb/yum/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF
    yum-config-manager MariaDB
    yum -y install MariaDB-client
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

#testCurrentNode(){
    #since node is (re)booted let test the GPUs again and mark the status in the tracking DB

#}

# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 90.install.service.automation.gpu.sh: START" >&2
    configMySQLcredentials
    #testCurrentNode
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 90.install.service.automation.gpu.sh: STOP" >&2
}

main "$@"