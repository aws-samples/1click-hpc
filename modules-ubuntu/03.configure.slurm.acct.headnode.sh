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
source '/etc/parallelcluster/cfnconfig'

configureFederatedSlurmDBD(){
    # slurm accounting must be preinstalled in the VPC.
    # slurm accouting secrets must be defined
    cp /tmp/hpc/sacct/slurm/slurm_fed_sacct.conf /tmp/ || exit 1
    cp /tmp/hpc/sacct/slurm/munge.key.gpg /tmp/ || exit 1
    export SLURM_FED_DBD_HOST="$(aws secretsmanager get-secret-value --secret-id "SLURM_FED_DBD_HOST" --query SecretString --output text --region us-east-1)"
    export SLURM_FED_PASSPHRASE="$(aws secretsmanager get-secret-value --secret-id "SLURM_FED_PASSPHRASE" --query SecretString --output text --region us-east-1)"
    /usr/bin/envsubst < slurm_fed_sacct.conf > "${SLURM_ETC}/slurm_sacct.conf"
    echo "include slurm_sacct.conf" >> "${SLURM_ETC}/slurm.conf"
    gpg --batch --passphrase "$SLURM_FED_PASSPHRASE" -d -o munge.key munge.key.gpg
    mv -f munge.key /etc/munge/munge.key
    chown munge:munge /etc/munge/munge.key
    chmod 600 /etc/munge/munge.key
    cp /etc/munge/munge.key /home/ubuntu/.munge/.munge.key
}

patchSlurmConfig() {
	sed -i "s/ClusterName=parallelcluster.*/ClusterName=parallelcluster-${stack_name}/" "/opt/slurm/etc/slurm.conf"
    sed -i "s/SlurmctldPort=6820-6829/SlurmctldPort=6820-6849/" "/opt/slurm/etc/slurm.conf"
    rm -f /var/spool/slurm.state/clustername
    ifconfig eth0 txqueuelen 512
}

installLuaSubmit() {
    apt-get install -y lua-devel luarocks redis
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
socket.http.TIMEOUT = 10

function getNumber(str)
    return string.gmatch(str, "%d+$")()
end

function apiCall(user, cluster, project, ngpu)
    local path = "http://internal-Int-AD-API-2115331254.us-east-1.elb.amazonaws.com/authnew"
    local payload = '{"user": "'..user..'", "parameters": {"cluster": "'..cluster..'", "project": "'..project..'"}, "numGpus": '..ngpu..'}'
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
        client:set(user..':'..project..':email', tab.email)
    else
        --print("[warning] Authorization endpoint failure. Attempting to use local cache.")
        tab.result = client:get(user..':'..project..':authorization')
        tab.message = client:get(user..':'..project..':message')
        tab.email = client:get(user..':'..project..':email')
    end
    if (tab.result == nil)
    then
        tab.result = "rejected"
        tab.message = "[error] General error encountered in the authorization system. Please try again later."
    end
    return tab
end
function slurm_job_submit(job_desc, submit_uid)
    stability_cluster = "parallelcluster-${stack_name}"
    if job_desc.account == nil then
        if job_desc.comment == nil then
            slurm.user_msg("[warning] You need to specify a project. Use '--account projectname'. Please be aware that '--comment projectname' will be deprecated.")
            slurm.user_msg("[warning] You can find your allocated projects by running 'id --name --groups'")
            return slurm.ESLURM_INVALID_ACCOUNT
        end
        job_desc.account = job_desc.comment
    end
    if  (job_desc.gres == nil) and (job_desc.tres_per_job == nil) and (job_desc.tres_per_node == nil) and (job_desc.tres_per_task == nil) and (job_desc.shared ~= 0) then
        slurm.log_info("User did not specified GPUS.")
        slurm.user_msg("[error] No GPUs were requested on the GPU cluster. If you do not need GPUs please use the CPU cluster instead.")
        return slurm.ERROR
    end
    ngpus = 0
    if job_desc.gres ~= nil then
        ngpus = getNumber(job_desc.gres)
    end
    if job_desc.tres_per_job ~= nil then
        ngpus = getNumber(job_desc.tres_per_job)
    end
    if job_desc.tres_per_node ~= nil then
        ngpus = getNumber(job_desc.tres_per_node)
    end
    if job_desc.tres_per_task ~= nil then
        ngpus = getNumber(job_desc.tres_per_task)
    end
    if job_desc.shared == 0 then
        ngpus = 8
    end
    local tab = apiCall(job_desc.user_name, stability_cluster, job_desc.account, ngpus)
    if tab.result=="rejected" then
        slurm.user_msg(tab.message)
        return slurm.ESLURM_INVALID_ACCOUNT
    else
        handle = io.popen("/opt/slurm/bin/sacctmgr show assoc format=qos where account=" .. job_desc.account .. ", user=" .. job_desc.user_name .. ", cluster=" .. stability_cluster .. " -n -P")
        result = handle:read("*a")
        handle:close()
        job_desc.qos = string.gsub(result, '%s+', '')
        if (tab.email ~= nil) then
            job_desc.mail_type = 1295
            job_desc.mail_user = tab.email
        end
        slurm.user_msg("[info] Determined priority for your job on the cluster " .. stability_cluster .. ": " .. job_desc.qos)
    end
    return slurm.SUCCESS
end
function slurm_job_modify(job_desc, job_rec, modify_uid)
    stability_cluster = "parallelcluster-${stack_name}"
    if job_desc.account == nil then
        if job_desc.comment == nil then
            slurm.user_msg("[warning] You need to specify a project. Use '--account projectname'. Please be aware that '--comment projectname' will be deprecated.")
            slurm.user_msg("[warning] You can find your allocated projects by running 'id --name --groups'")
            return slurm.ESLURM_INVALID_ACCOUNT
        end
        job_desc.account = job_desc.comment
    end
    if  (job_desc.gres == nil) and (job_desc.tres_per_job == nil) and (job_desc.tres_per_node == nil) and (job_desc.tres_per_task == nil) and (job_desc.shared ~= 0) then
        slurm.log_info("User did not specified GPUS.")
        slurm.user_msg("[error] No GPUs were requested on the GPU cluster. If you do not need GPUs please use the CPU cluster instead.")
        return slurm.ERROR
    end
    ngpus = 0
    if job_desc.gres ~= nil then
        ngpus = getNumber(job_desc.gres)
    end
    if job_desc.tres_per_job ~= nil then
        ngpus = getNumber(job_desc.tres_per_job)
    end
    if job_desc.tres_per_node ~= nil then
        ngpus = getNumber(job_desc.tres_per_node)
    end
    if job_desc.tres_per_task ~= nil then
        ngpus = getNumber(job_desc.tres_per_task)
    end
    if job_desc.shared == 0 then
        ngpus = 8
    end
    local tab = apiCall(job_desc.user_name, stability_cluster, job_desc.account, ngpus)
    if tab.result=="rejected" then
        slurm.user_msg(tab.message)
        return slurm.ESLURM_INVALID_ACCOUNT
    else
        handle = io.popen("/opt/slurm/bin/sacctmgr show assoc format=qos where account=" .. job_desc.account .. ", user=" .. job_desc.user_name .. ", cluster=" .. stability_cluster .. " -n -P")
        result = handle:read("*a")
        handle:close()
        job_desc.qos = string.gsub(result, '%s+', '')
        if (tab.email ~= nil) then
            job_desc.mail_type = 1295
            job_desc.mail_user = tab.email
        end
        slurm.user_msg("[info] Determined priority for your job on the cluster " .. stability_cluster .. ": " .. job_desc.qos)
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
    configureFederatedSlurmDBD
    patchSlurmConfig
    restartSlurmDaemons
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 03.configure.slurm.acct.headnode.sh: STOP" >&2
}

main "$@"