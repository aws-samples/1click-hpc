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
    # install pre-requisites
    yum -y -q install java-latest-openjdk
    wget -nv -P /tmp/packages https://dn3uclhgxk1jt.cloudfront.net/enginframe/packages/enginframe-latest.jar || exit 1
    
    aws s3 cp --quiet "${post_install_base}/packages/efinstall.config" /tmp/packages/ --region "${cfn_region}" || exit 1

    # set permissions and uncompress
    chmod 755 -R /tmp/packages/*
    enginframe_jar=$(find /tmp/packages -type f -name 'enginframe-*.jar')
    # some checks
    [[ -z ${enginframe_jar} ]] && \
        echo "[ERROR] missing enginframe jar" && return 1
    [[ ! -f /tmp/packages/efinstall.config ]] && \
        echo "[ERROR] missing efinstall.config" && return 1

    # update java path
    java_path=$(readlink /etc/alternatives/java | sed 's/\/bin\/java//')
    sed -i \
        "s/^kernel.java.home = .*$/kernel.java.home = ${java_path//\//\\/}/" \
        /tmp/packages/efinstall.config
    # use shared folder as NICE_ROOT
    sed -i \
        "s/^nice.root.dir.ui = .*$/nice.root.dir.ui = ${NICE_ROOT//\//\\/}/" \
        /tmp/packages/efinstall.config
    sed -i \
        "s/^ef.spooler.dir = .*$/ef.spooler.dir = ${NICE_ROOT//\//\\/}\/enginframe\/spoolers/" \
        /tmp/packages/efinstall.config
    sed -i \
        "s/^ef.repository.dir = .*$/ef.repository.dir = ${NICE_ROOT//\//\\/}\/enginframe\/repository/" \
        /tmp/packages/efinstall.config
    sed -i \
        "s/^ef.sessions.dir = .*$/ef.sessions.dir = ${NICE_ROOT//\//\\/}\/enginframe\/sessions/" \
        /tmp/packages/efinstall.config
    sed -i \
        "s/^ef.data.root.dir = .*$/ef.data.root.dir = ${NICE_ROOT//\//\\/}\/enginframe\/data/" \
        /tmp/packages/efinstall.config
    sed -i \
        "s/^ef.logs.root.dir = .*$/ef.logs.root.dir = ${NICE_ROOT//\//\\/}\/enginframe\/logs/" \
        /tmp/packages/efinstall.config
    sed -i \
        "s/^ef.temp.root.dir = .*$/ef.temp.root.dir = ${NICE_ROOT//\//\\/}\/enginframe\/tmp/" \
        /tmp/packages/efinstall.config
    sed -i \
        "s/^kernel.server.tomcat.https.ef.hostname = .*$/kernel.server.tomcat.https.ef.hostname = ${host_name}/" \
        /tmp/packages/efinstall.config

    # add EnginFrame users if not already exist
    id -u efnobody &>/dev/null || adduser efnobody

    echo "${ec2user_pass}" | passwd ec2-user --stdin

    if [[ -d "${SHARED_FS_DIR}/nice" ]]; then
        mv  -f "${SHARED_FS_DIR}/nice" "${SHARED_FS_DIR}/nice.$(date "+%d-%m-%Y-%H-%M").BAK"
    fi
    
    # finally, launch EnginFrame installer
    ( cd /tmp/packages
      java -jar "${enginframe_jar}" --text --batch )
}

startEnginFrame() {
  systemctl start enginframe
}


# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 10.install.enginframe.headnode.sh: START" >&2
    installEnginFrame
    startEnginFrame
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 10.install.enginframe.headnode.sh: STOP" >&2
}

main "$@"