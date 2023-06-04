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
                ["Authorization"] = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJodHRwOi8vc2NoZW1hcy54bWxzb2FwLm9yZy93cy8yMDA1LzA1L2lkZW50aXR5L2NsYWltcy9uYW1lIjoiYWRtaW4iLCJodHRwOi8vc2NoZW1hcy54bWxzb2FwLm9yZy93cy8yMDA1LzA1L2lkZW50aXR5L2NsYWltcy9oYXNoIjoiMmVhMjFiODgtZDM1My00NGI4LThiNTYtYjIwNDhlMGY4ZTVmIiwic3ViIjoiUG93ZXJTaGVsbFVuaXZlcnNhbCIsImh0dHA6Ly9zY2hlbWFzLm1pY3Jvc29mdC5jb20vd3MvMjAwOC8wNi9pZGVudGl0eS9jbGFpbXMvcm9sZSI6Ik9wZXJhdG9yIiwibmJmIjoxNjgyMTgwODE0LCJleHAiOjIxNDAxMDA3NjAsImlzcyI6Iklyb25tYW5Tb2Z0d2FyZSIsImF1ZCI6IlBvd2VyU2hlbGxVbml2ZXJzYWwifQ.qeeAV6UFgC1mzgqZ8IxCeR6l5XeMIh0DZDuD1tuqX8I",
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
    stability_cluster = "sagemaker"
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
    stability_cluster = "sagemaker"
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
