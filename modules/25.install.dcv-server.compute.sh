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

set -x
set -e

installSimpleExternalAuth() {
    
    yum -y -q install nice-dcv-*/nice-dcv-simple-external-authenticator-*.rpm
    
    systemctl start dcvsimpleextauth.service

}

installMissingLib() {
    yum -y -q install ImageMagick
}

configureDCVexternalAuth() {
    
    pattern='\[security\]'
    replace='&\n'
    replace+="auth-token-verifier=\"http://localhost:8444\""
    cp '/etc/dcv/dcv.conf' "/etc/dcv/dcv.conf.$(date --iso=s --utc)"
    # remove duplicates if any
    #sed -i -e '/^ *\(administrators\|ca-file\|auth-token-verifier\) *=.*$/d' '/etc/dcv/dcv.conf'
    sed -i -e "s|${pattern}|${replace}|" '/etc/dcv/dcv.conf'

}

restartDCV() {
    
    systemctl restart dcvserver.service

}

# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] install.dcv-server.compute.sh: START" >&2

    wget -nv https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-el7-x86_64.tgz
    tar zxvf nice-dcv-el7-x86_64.tgz
    installSimpleExternalAuth
    dcvusbdriverinstaller --quiet
    
    installMissingLib
    configureDCVexternalAuth
    restartDCV

    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] install.dcv-server.compute.sh: STOP" >&2
}

main "$@"