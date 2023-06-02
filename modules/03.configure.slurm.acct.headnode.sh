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
source "/etc/parallelcluster/cfnconfig"

configureFederatedSlurmDBD(){
    # slurm accounting must be preinstalled in the VPC.
    # slurm accounting secrets must be defined
    aws s3 cp --quiet "${post_install_base}/sacct/slurm/slurm_fed_sacct.conf" /tmp/ --region "${cfn_region}" || exit 1
    aws s3 cp --quiet "${post_install_base}/sacct/slurm/munge.key.gpg" /tmp/ --region "${cfn_region}" || exit 1
    export SLURM_FED_DBD_HOST="$(aws secretsmanager get-secret-value --secret-id "SLURM_FED_DBD_HOST" --query SecretString --output text --region "${cfn_region}")"
    export SLURM_FED_PASSPHRASE="$(aws secretsmanager get-secret-value --secret-id "SLURM_FED_PASSPHRASE" --query SecretString --output text --region "${cfn_region}")"
    /usr/bin/envsubst < slurm_fed_sacct.conf > "${SLURM_ETC}/slurm_sacct.conf"
    echo "include slurm_sacct.conf" >> "${SLURM_ETC}/slurm.conf"
    gpg --batch --passphrase "$SLURM_FED_PASSPHRASE" -d -o munge.key munge.key.gpg
    mv -f munge.key /etc/munge/munge.key
    chown munge:munge /etc/munge/munge.key
    chmod 600 /etc/munge/munge.key
    cp /etc/munge/munge.key /home/ec2-user/.munge/.munge.key
}

patchSlurmConfig() {
	sed -i "s/ClusterName=parallelcluster.*/ClusterName=parallelcluster-${stack_name}/" "/opt/slurm/etc/slurm.conf"
    #sed -i "s/SlurmctldPort=6820-6829/SlurmctldPort=6820-6849/" "/opt/slurm/etc/slurm.conf"
    rm -f /var/spool/slurm.state/clustername
    #ifconfig eth0 txqueuelen 512
}

installLuaSubmit() {
    yum install -y lua-devel luarocks redis
    luarocks install redis-lua 
    luarocks install lua-cjson
    export token="$(aws secretsmanager get-secret-value --secret-id "ADtokenPSU" --query SecretString --output text --region "${cfn_region}")"
cat > /opt/slurm/etc/job_submit.lua << EOF
local redis = require 'redis'
local client = redis.connect('127.0.0.1', 6379)
local socket = require("socket")
local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require('cjson')

function apiCall(user,project,ngpu)
    local path = "http://internal-Int-AD-API-2115331254.us-east-1.elb.amazonaws.com/auth"
    local payload = '{"user": "'..user..'", "parameters": {"project": "'..project..'"}, "numGpus": '..ngpu..'}'
    local response_body = { }
    local tab = { }
    local res, code, response_headers, status = http.request
        {
            url = path,
            method = "POST",
            headers =
            {
                ["Authorization"] = "$token",
                ["Content-Type"] = "application/json",
                ["Content-Length"] = payload:len()
            },
            source = ltn12.source.string(payload),
            sink = ltn12.sink.table(response_body),
            create=function()
                local req_sock = socket.tcp()
                req_sock:settimeout(3, 'b')
                req_sock:settimeout(7, 't')
                return req_sock
            end
        }
    if (res ~= nil)
    then
        tab = json.decode(table.concat(response_body))
        --print('[0] Result: ' .. tab.result .. ' Message: ' .. tab.message,-1)
    else
        code=400
    end
    if (code==200)
    then
        client:set(user..':'..project..':authorization', tab.result)
        client:set(user..':'..project..':message', tab.message)
    else
        --print("[warning] Authorization endpoint failure. Attempting to use local cache.")
        tab.result = client:get(user..':'..project..':authorization')
        tab.message = client:get(user..':'..project..':message')
    end
    if (tab.result == nil)
    then
        tab.result = "rejected"
        tab.message = "[error] General error encountered in the authorization system. Please try again later."
    end
    return tab
end
function slurm_job_submit(job_desc, part_list, submit_uid)
    if job_desc.account == nil then
        if job_desc.comment == nil then
            slurm.log_user("You need to specify a project. Use '--account projectname'. Please be aware that '--comment projectname' will be deprecated.")
            slurm.log_user("You can find your allocated projects by running 'id --name --groups'")
            return slurm.ESLURM_INVALID_ACCOUNT
        end
        job_desc.account = job_desc.comment
    end
    local tab = apiCall(job_desc.user_name, job_desc.account,0)
    if tab.result=="rejected" then
        slurm.log_user(tab.message)
        return slurm.ESLURM_INVALID_ACCOUNT
    end
    return slurm.SUCCESS
end
function slurm_job_modify(job_desc, job_rec, part_list, modify_uid)
    if job_desc.account == nil then
        if job_desc.comment == nil then
            slurm.log_user("[warning] You need to specify a project. Use '--account projectname'. Please be aware that '--comment projectname' will be deprecated.")
            slurm.log_user("[warning] You can find your allocated projects by running 'id --name --groups'")
            return slurm.ESLURM_INVALID_ACCOUNT
        end
        job_desc.account = job_desc.comment
    end
    local tab = apiCall(job_desc.user_name, job_desc.account,0)
    if tab.result=="rejected" then
        slurm.log_user(tab.message)
        return slurm.ESLURM_INVALID_ACCOUNT
    end
    return slurm.SUCCESS
end
return slurm.SUCCESS
EOF

echo 'JobSubmitPlugins=lua' >> /opt/slurm/etc/slurm.conf

    cat > /etc/sudoers.d/100-AD-admins << EOF

EOF
}

restartSlurmDaemons() {
    set +e
    systemctl restart munge
    /opt/slurm/bin/sacctmgr -i create cluster ${stack_name}
    /opt/slurm/bin/sacctmgr -i create account name=none
    /opt/slurm/bin/sacctmgr -i create user ${cfn_cluster_user} cluster=${stack_name} account=none
    systemctl restart slurmctld
}

# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 03.configure.slurm.acct.headnode.sh: START" >&2
    patchSlurmConfig
    configureFederatedSlurmDBD
    restartSlurmDaemons
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 03.configure.slurm.acct.headnode.sh: STOP" >&2
}

main "$@"