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


# Installs EnginFrame on the headnode

set -x
set -e

# install EnginFrame
# ----------------------------------------------------------------------------
installEnginFrame() {

    export EF_RANDOM=$(echo $RANDOM | md5sum | head -c 8; echo;)
    
    wget -nv -P /tmp/packages https://dn3uclhgxk1jt.cloudfront.net/enginframe/packages/enginframe-latest.jar || exit 1
    
    aws s3 cp --quiet "${post_install_base}/enginframe/efinstall.config" /tmp/packages/ --region "${cfn_region}" || exit 1
    export EF_DB_PASS="$(aws secretsmanager get-secret-value --secret-id "${stack_name}-DB" --query SecretString --output text --region "${cfn_region}")" 

    # set permissions and uncompress
    chmod 755 -R /tmp/packages/*
    enginframe_jar=$(find /tmp/packages -type f -name 'enginframe-*.jar')
    # some checks
    [[ -z ${enginframe_jar} ]] && \
        echo "[ERROR] missing enginframe jar" && return 1
    [[ ! -f /tmp/packages/efinstall.config ]] && \
        echo "[ERROR] missing efinstall.config" && return 1

    cat <<-EOF >> /tmp/packages/efinstall.config
kernel.java.home = /usr/lib/jvm/java-1.8.0-openjdk/
nice.root.dir.ui = ${NICE_ROOT}
ef.spooler.dir = ${NICE_ROOT}/enginframe/spoolers/
ef.repository.dir = ${NICE_ROOT}/enginframe/repository/
ef.sessions.dir = ${NICE_ROOT}/enginframe/sessions/
ef.data.root.dir = ${NICE_ROOT}/enginframe/data/
ef.logs.root.dir = ${NICE_ROOT}/enginframe/logs/
ef.temp.root.dir = ${NICE_ROOT}/enginframe/tmp/
kernel.server.tomcat.https.ef.hostname = ${host_name}
kernel.ef.db.url = jdbc\:mysql\://${SLURM_DB_ENDPOINT}\:3306/EnginFrameDB_${EF_RANDOM}
kernel.ef.db.admin.password = ${EF_DB_PASS}
EOF

    # add EnginFrame users if not already exist
    id -u efnobody &>/dev/null || adduser efnobody

    echo "${ec2user_pass}" | passwd ec2-user --stdin

    if [[ -d "${SHARED_FS_DIR}/nice/${stack_name}" ]]; then
        mv  -f "${SHARED_FS_DIR}/nice/${stack_name}" "${SHARED_FS_DIR}/nice/${stack_name}.$(date "+%d-%m-%Y-%H-%M").BAK"
    fi
    
    # finally, launch EnginFrame installer
    ( cd /tmp/packages
      /usr/lib/jvm/java-1.8.0-openjdk/bin/java -jar "${enginframe_jar}" --text --batch )
}

createEnginFrameDB(){
    
    #FIXME: use latest link
    wget -nv -P "${EF_ROOT}/WEBAPP/WEB-INF/lib/" https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.28/mysql-connector-java-8.0.28.jar
    chown ec2-user:efnobody "${EF_ROOT}/WEBAPP/WEB-INF/lib/mysql-connector-java-8.0.28.jar"

    
    aws s3 cp --quiet "${post_install_base}/enginframe/mysql/efdb.config" /tmp/ --region "${cfn_region}" || exit 1
    aws s3 cp --quiet "${post_install_base}/enginframe/mysql/ef.mysql" /tmp/ --region "${cfn_region}" || exit 1
    
    /usr/bin/envsubst < efdb.config > efdb.pass.config
    /usr/bin/envsubst < ef.mysql > ef.pass.mysql
    
    mysql --defaults-extra-file="efdb.pass.config" < "ef.pass.mysql"
    rm efdb.pass.config efdb.config ef.mysql ef.pass.mysql
    
}

customizeEnginFrame() {
    aws s3 cp --quiet "${post_install_base}/enginframe/fm.browse.ui" "${EF_ROOT}/plugins/applications/bin/" --region "${cfn_region}" || exit 1
    chown ec2-user:efnobody "${EF_ROOT}/plugins/applications/bin/fm.browse.ui"
    chmod 755 "${EF_ROOT}/plugins/applications/bin/fm.browse.ui"

    sed -i \
        "s/^HY_CONNECT_SESSION_MAX_WAIT=.*$/HY_CONNECT_SESSION_MAX_WAIT='600'/" \
        "${EF_ROOT}/plugins/hydrogen/conf/ui.hydrogen.conf"
}

startEnginFrame() {
  systemctl start enginframe
}


# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 10.install.enginframe.headnode.sh: START" >&2
    installEnginFrame
    EF_TOP="${NICE_ROOT}/enginframe"
    unset EF_VERSION
    source "${EF_TOP}/current-version"
    export EF_ROOT="${EF_TOP}/${EF_VERSION}/enginframe"
    createEnginFrameDB
    customizeEnginFrame
    startEnginFrame
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 10.install.enginframe.headnode.sh: STOP" >&2
}

main "$@"