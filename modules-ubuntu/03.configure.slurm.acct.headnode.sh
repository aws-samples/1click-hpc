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
# SOFTWARE OR THE USE OR OTHER DEALINGS I
set -x
set -e
source '/etc/parallelcluster/cfnconfig'

configureFederatedSlurmDBD(){
    # slurm accounting must be preinstalled in the VPC.
    # slurm accouting secrets must be defined
    # SLURM_ETC is missing from the environment
    SLURM_ETC=/opt/slurm/etc
    cp /tmp/hpc/sacct/slurm/slurm_fed_sacct.conf /tmp/ || exit 1
    cp /tmp/hpc/sacct/slurm/munge.key.gpg /tmp/ || exit 1
    export SLURM_FED_DBD_HOST="$(aws secretsmanager get-secret-value --secret-id "SLURM_FED_DBD_PCLUSTER_WEST" --query SecretString --output text --region ${cfn_region} --cli-connect-timeout 1)"
    export SLURM_FED_PASSPHRASE="$(aws secretsmanager get-secret-value --secret-id "SLURM_FED_PASSPHRASE" --query SecretString --output text --region ${cfn_region} --cli-connect-timeout 1)"
    /usr/bin/envsubst < /tmp/slurm_fed_sacct.conf > "${SLURM_ETC}/slurm_sacct.conf"
    echo "include slurm_sacct.conf" >> "${SLURM_ETC}/slurm.conf"
    gpg --batch --ignore-mdc-error --passphrase "$SLURM_FED_PASSPHRASE" -d -o /tmp/munge.key /tmp/munge.key.gpg
    mv -f /tmp/munge.key /etc/munge/munge.key
    chown munge:munge /etc/munge/munge.key
    chmod 600 /etc/munge/munge.key
    if [ -d /home/ubuntu/.munge ]; then
        cp /etc/munge/munge.key /home/ubuntu/.munge/.munge.key
    fi
    if [ -d /opt/parallelcluster/shared/.munge ]; then
        cp /etc/munge/munge.key /opt/parallelcluster/shared/.munge/.munge.key
    fi
    if [ -d /opt/parallelcluster/shared_login_nodes/.munge ]; then
        cp /etc/munge/munge.key /opt/parallelcluster/shared_login_nodes/.munge/.munge.key
    fi
    systemctl restart munge
}

patchSlurmConfig() {
	sed -i "s/ClusterName=parallelcluster.*/ClusterName=${stack_name}/" "/opt/slurm/etc/slurm.conf"
    sed -i "s/SlurmctldPort=6820-6829/SlurmctldPort=6820-6849/" "/opt/slurm/etc/slurm.conf"
    rm -f /var/spool/slurm.state/clustername

    #need to add  TRESBillingWeights="CPU=0.0,Mem=0.0" to each cpu partition to avoid AssocGrpBillingMinutes problem
    for file in /opt/slurm/etc/pcluster/*_partition.conf; do
        sed -i '${s/$/ TRESBillingWeights="CPU=0.0,Mem=0.0"/}' $file
    done
}

installLuaSubmit() {
    apt-get install -y redis
    apt-get remove -y lua5.1 liblua5.1-dev
    #install lua 5.3.5 from source
    curl -R -O https://www.lua.org/ftp/lua-5.3.5.tar.gz
    tar -zxf lua-5.3.5.tar.gz
    cd lua-5.3.5
    make linux test
    make install
    #install luarocks from source
    wget https://luarocks.org/releases/luarocks-3.8.0.tar.gz
    tar zxpf luarocks-3.8.0.tar.gz
    cd luarocks-3.8.0
    ./configure --with-lua-include=/usr/local/include
    make
    make install
    cd /usr/local
    /usr/local/bin/luarocks install --tree  . luasocket
    /usr/local/bin/luarocks install --tree . redis-lua 
    /usr/local/bin/luarocks install --tree . lua-cjson
    export token="$(aws secretsmanager get-secret-value --secret-id "ADtokenPSU" --query SecretString --output text --region ${cfn_region})"
    export AD_API_BASE="$(aws secretsmanager get-secret-value --secret-id "AD_API_BASE" --query SecretString --output text --region ${cfn_region})"

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
    local path = "http://".."$AD_API_BASE".."/authnew"
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
    stability_cluster = "${stack_name}"
    if job_desc.account == nil then
        if job_desc.comment == nil then
            slurm.user_msg("[warning] You need to specify a project. Use '--account projectname'. Please be aware that '--comment projectname' will be deprecated.")
            slurm.user_msg("[warning] You can find your allocated projects by running 'id --name --groups'")
            return slurm.ESLURM_INVALID_ACCOUNT
        end
        job_desc.account = job_desc.comment
    end
    ngpus = 0
    local tab = apiCall(job_desc.user_name, stability_cluster, job_desc.account, ngpus)
    if tab.result=="rejected" and job_desc.user_name ~= "root" then
        slurm.user_msg(tab.message)
        return slurm.ESLURM_INVALID_ACCOUNT
    else
        if job_desc.qos == nil then
            handle = io.popen("/opt/slurm/bin/sacctmgr show assoc format=defaultqos where account=" .. job_desc.account .. ", user=" .. job_desc.user_name .. ", cluster=" .. stability_cluster .. " -n -P")
            result = handle:read("*a")
            handle:close()
            job_desc.qos = string.gsub(result, '%s+', '')
        else
            goodqos = false
            handle = io.popen("/opt/slurm/bin/sacctmgr show assoc format=qos where account=" .. job_desc.account .. ", user=" .. job_desc.user_name .. ", cluster=" .. stability_cluster .. " -n -P")
            result = handle:read("*a")
            handle:close()
            for w in string.gsub(result, '%s+', ''):gmatch("([^,]+)") do 
                if w == job_desc.qos then
                    goodqos = true
                    break
                end
            end
            if goodqos == false then
                slurm.user_msg("[error] You cannot use the QOS " .. job_desc.qos .. " for this project. Please use one of the following: " .. result)
                return slurm.ESLURM_INVALID_ACCOUNT
            end
        end
        if (tab.email ~= nil and job_desc.user_name ~= "root") then
            job_desc.mail_type = 1295
            job_desc.mail_user = tab.email
        end
        slurm.user_msg("[info] Determined priority for your job on the cluster " .. stability_cluster .. ": " .. job_desc.qos)
    end
    return slurm.SUCCESS
end
function slurm_job_modify(job_desc, job_rec, modify_uid)
    stability_cluster = "${stack_name}"
    if job_desc.account == nil then
        if job_desc.comment == nil then
            slurm.user_msg("[warning] You need to specify a project. Use '--account projectname'. Please be aware that '--comment projectname' will be deprecated.")
            slurm.user_msg("[warning] You can find your allocated projects by running 'id --name --groups'")
            return slurm.ESLURM_INVALID_ACCOUNT
        end
        job_desc.account = job_desc.comment
    end
    ngpus = 0
    local tab = apiCall(job_desc.user_name, stability_cluster, job_desc.account, ngpus)
    if tab.result=="rejected" and job_desc.user_name ~= "root" then
        slurm.user_msg(tab.message)
        return slurm.ESLURM_INVALID_ACCOUNT
    else
        if job_desc.qos == nil then
            handle = io.popen("/opt/slurm/bin/sacctmgr show assoc format=defaultqos where account=" .. job_desc.account .. ", user=" .. job_desc.user_name .. ", cluster=" .. stability_cluster .. " -n -P")
            result = handle:read("*a")
            handle:close()
            job_desc.qos = string.gsub(result, '%s+', '')
        else
            goodqos = false
            handle = io.popen("/opt/slurm/bin/sacctmgr show assoc format=qos where account=" .. job_desc.account .. ", user=" .. job_desc.user_name .. ", cluster=" .. stability_cluster .. " -n -P")
            result = handle:read("*a")
            handle:close()
            for w in string.gsub(result, '%s+', ''):gmatch("([^,]+)") do 
                if w == job_desc.qos then
                    goodqos = true
                    break
                end
            end
            if goodqos == false then
                slurm.user_msg("[error] You cannot use the QOS " .. job_desc.qos .. " for this project. Please use one of the following: " .. result)
                return slurm.ESLURM_INVALID_ACCOUNT
            end
        end
        if (tab.email ~= nil and job_desc.user_name ~= "root") then
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
# add domain admins as sudoers
%Sudoers  ALL=(ALL) NOPASSWD:ALL
EOF
}

restartSlurmDaemons() {
    set +e
    systemctl restart munge
    /opt/slurm/bin/sacctmgr -i create cluster ${stack_name}
    systemctl restart slurmctld
}

# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 03.configure.slurm.acct.headnode.sh: START" >&2
    configureFederatedSlurmDBD
    patchSlurmConfig
    installLuaSubmit
    restartSlurmDaemons
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 03.configure.slurm.acct.headnode.sh: STOP" >&2
}

main "$@"