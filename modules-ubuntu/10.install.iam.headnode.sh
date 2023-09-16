#!/bin/bash

# depends on 03.configure.slurm.acct.headnode.sh
set -x
set -e
source '/etc/parallelcluster/cfnconfig'

installBBuffers() {
    export APIURL="$(aws secretsmanager get-secret-value --secret-id "IamApiDev-IamApiUrlSecret" --query SecretString --output text --region us-west-2)" #todo: do not hardcode, add secret name as CF parameter
    export APISECRET="$(aws secretsmanager get-secret-value --secret-id "IamApiDev-HeadNodeSecret" --query SecretString --output text --region us-west-2)" #todo: do not hardcode, add secret name as CF parameter

    echo " " >> /opt/slurm/etc/slurm.conf
    echo "#BURST BUFFER CONFIGURATION" >> /opt/slurm/etc/slurm.conf
    echo "BurstBufferType=burst_buffer/lua" >> /opt/slurm/etc/slurm.conf
    echo "DebugFlags=BurstBuffer" >> /opt/slurm/etc/slurm.conf

    echo " " >> /opt/slurm/etc/slurm.conf
    echo "#TASK PROLOG CONFIGURATION" >> /opt/slurm/etc/slurm.conf
    echo "TaskProlog=/opt/slurm/etc/task_prolog.sh" >> /opt/slurm/etc/slurm.conf

	#activate burst buffers with job_submit.lua
	sed -i '/^\s*stability_cluster.*/a\    job_desc.burst_buffer = "#BB_LUA"' "/opt/slurm/etc/job_submit.lua"

cat > /opt/slurm/etc/task_prolog.sh << EOF
#!/bin/bash
host=\$(hostname)
cluster=\$(echo \$SLURM_WORKING_CLUSTER | cut -d':' -f1)
if [[ "\${AWS_CONTAINER_CREDENTIALS_FULL_URI}" != *"roleSessionName"* ]];then
    echo "export AWS_CONTAINER_CREDENTIALS_FULL_URI=\${AWS_CONTAINER_CREDENTIALS_FULL_URI}?roleSessionName=\${SLURM_JOB_ACCOUNT}-\${cluster}-\${USER}-\${host}"
fi
EOF

cat > /opt/slurm/etc/burst_buffer.lua << EOF
lua_script_name="burst_buffer.lua"
local socket = require("socket")
local https = require("ssl.https")
local ltn12 = require("ltn12")
local json = require('cjson')
socket.http.TIMEOUT = 10
local headnodekey = "$APISECRET"

function apiCall(user, cluster, project, jobid)
    --todo: do not hardcode
    local path = "$APIURL".."sessions"
    local payload = '{"sessionId": "'..jobid..'", "projectId": "'..project..'", "clusterName": "'..cluster..'", "clusterUser": "'..user..'","submittedTime":"'..os.date("%Y-%m-%dT%H:%M:%S")..'"}'
    local response_body = { }
    local tab = { }
    local res, code, response_headers, status = https.request
        {
            url = path,
            method = "POST",
            headers =
            {   --todo: do not hardcode
                ["Authorization"] = headnodekey,
                ["Content-Type"] = "application/json",
                ["Content-Length"] = payload:len()
            },
            source = ltn12.source.string(payload),
            sink = ltn12.sink.table(response_body),
        }
    slurm.log_info("API call 1 returned code: "..code)
    if (res ~= nil)
    then
        tab = json.decode(table.concat(response_body))
        --print('[0] Result: ' .. tab.result .. ' Message: ' .. tab.message,-1)
    end
    return tab
end

function apiCall2(user, cluster, jobid)
    --todo: do not hardcode and find better way to identify the row to invalidate, use user, cluster and project as well
	local path = "$APIURL".."sessions/"..jobid.."/cluster/"..cluster
    local payload = '{"status": "COMPLETED"}'
    local response_body = { }
    local tab = { }
    local res, code, response_headers, status = https.request
        {
            url = path,
            method = "PUT",
            headers =
            {   --todo: do not hardcode
                ["Authorization"] = headnodekey,
                ["Content-Type"] = "application/json",
                ["Content-Length"] = payload:len()
            },
            source = ltn12.source.string(payload),
            sink = ltn12.sink.table(response_body),
        }
    if (res ~= nil)
    then
        tab = json.decode(table.concat(response_body))
        --print('[0] Result: ' .. tab.result .. ' Message: ' .. tab.message,-1)
    end
    return tab
end

--Print job_info to the log file
function print_job_info(job_info)
	account = job_info["account"]
	array_job_id = job_info["array_job_id"]
	array_task_id = job_info["array_task_id"]
	array_max_tasks = job_info["array_max_tasks"]
	array_task_str = job_info["array_task_str"]
	gres_detail_cnt = job_info["gres_detail_cnt"]
	if (gres_detail_cnt ~= 0) then
		--[[
		--This keys of this table are the index starting with 1 and
		--ending with gres_detail_cnt. The index is the offset of the
		--node in the job (index==1 is the first node in the job).
		--
		--The values of this table are strings representing the gres
		--currently allocated to the job on each node. The format
		--is a comma-separated list of:
		--
		--For gres with a file:
		--<gres_name>[:<gres_type>]:<count>(IDX:<gres_index>)
		--
		--For count-only gres:
		--<gres_name>[:<gres_type>](CNT:<count>)
		--
		--This field is only non-nil if the job is running and has
		--allocated gres; hence it only applies
		--to slurm_bb_pre_run since that is the only hook called with
		--a job in the running state.
		--]]
		gres_table = job_info["gres_detail_str"]
		sep = "\n\t\t"
		gres_detail_str = string.format("%s%s",
			sep, table.concat(gres_table, sep))
	else
		gres_detail_str = nil
	end
	gres_total = job_info["gres_total"]
	group_id = job_info["group_id"]
	het_job_id = job_info["het_job_id"]
	het_job_id_set = job_info["het_job_id_set"]
	het_job_offset = job_info["het_job_offset"]
	job_id = job_info["job_id"]
	job_state = job_info["job_state"]
	nodes = job_info["nodes"]
	partition = job_info["partition"]
        userid = job_info["user_id"]
        username = job_info["user_name"]

	slurm.log_info("%s:\
        JobId=%u\
	account=%s\
        userid=%s\
        username=%s\
	array_job_id=%u\
	array_task_id=%u\
	array_max_tasks=%u\
	array_task_str=%s\
	gres_total=%s\
	group_id=%u\
	het_job_id=%u\
	het_job_offset=%u\
	job_state=%u\
	nodes=%s\
	partition=%s\
",
		lua_script_name, job_id, account, userid, username, array_job_id, array_task_id,
		array_max_tasks, array_task_str, gres_total, group_id,
		het_job_id, het_job_offset, job_state, nodes, partition)

	if (gres_detail_cnt ~= 0) then
		slurm.log_info("complete gres_detail_str=\n%s",
			gres_detail_str)
		for i,v in ipairs(gres_table) do
			slurm.log_info("Node index = %u, gres_detail_str = %s",
				i, gres_table[i])
		end
	end
end


--This requires lua-posix to be installed
function posix_sleep(n)
	local Munistd = require("posix.unistd")
	local rc
	slurm.log_info("sleep for %u seconds", n)
	rc = Munistd.sleep(n)
	--rc will be 0 if successful or non-zero for amount of time left
	--to sleep
	return rc
end

--This commented out function is a wrapper for the posix "sleep"
--function in the lua-posix posix.unistd module.
function sleep_wrapper(n)
	return slurm.SUCCESS, ""
	--local rc, ret_str
	--rc = posix_sleep(n)
	--if (rc ~= 0) then
	--	ret_str = "Sleep interrupted, " .. tostring(rc) .. " seconds left"
	--	rc = slurm.ERROR
	--else
	--	ret_str = "Success"
	--	rc = slurm.SUCCESS
	--end
	--return rc, ret_str
end

--[[
--slurm_bb_job_process
--
--WARNING: This function is called synchronously from slurmctld and must
--return quickly.
--
--This function is called on job submission.
--This example reads, logs, and returns the job script.
--If this function returns an error, the job is rejected and the second return
--value (if given) is printed where salloc, sbatch, or srun was called.
--]]
function slurm_bb_job_process(job_script, uid, gid, job_info)
	local contents
	slurm.log_info("%s: slurm_bb_job_process(). job_script=%s, uid=%s, gid=%s",
		lua_script_name, job_script, uid, gid)
	io.input(job_script)
	contents = io.read("*all")

	local rc, str = slurm.job_info_to_string(job_info)
	slurm.log_info("slurm.job_info_to_string returned:\nrc=%d, str=\n%s",
		rc, str)

	return slurm.SUCCESS, contents
end

--[[
--slurm_bb_pools
--
--WARNING: This function is called from slurmctld and must return quickly.
--
--This function is called on slurmctld startup, and then periodically while
--slurmctld is running.
--
--You may specify "pools" of resources here. If you specify pools, a job may
--request a specific pool and the amount it wants from the pool. Slurm will
--subtract the job's usage from the pool at slurm_bb_data_in and Slurm will
--add the job's usage of those resources back to the pool after
--slurm_bb_teardown.
--A job may choose not to specify a pool even you pools are provided.
--If pools are not returned here, Slurm does not track burst buffer resources
--used by jobs.
--
--If pools are desired, they must be returned as the second return value
--of this function. It must be a single JSON string representing the pools.
--]]
function slurm_bb_pools()

	slurm.log_info("%s: slurm_bb_pools().", lua_script_name)

	--This commented out code specifies pools in a file:
	--local pools_file, pools
	--pools_file = "/path/to/file"

	--io.input(pools_file)
	--pools = io.read("*all")
	--slurm.log_info("Pools file:\n%s", pools)

	--This specifies pools inline:
	local pools
	pools ="\
{\
\"pools\":\
  [\
    { \"id\":\"pool1\", \"quantity\":1000, \"granularity\":1024 },\
    { \"id\":\"pool2\", \"quantity\":5, \"granularity\":2 },\
    { \"id\":\"pool3\", \"quantity\":4, \"granularity\":1 },\
    { \"id\":\"pool4\", \"quantity\":25000, \"granularity\":1 }\
  ]\
}"

	return slurm.SUCCESS, pools
end

--[[
--slurm_bb_job_teardown
--
--This function is called asynchronously and is not required to return quickly.
--This function is normally called after the job completes (or is cancelled).
--]]
function slurm_bb_job_teardown(job_id, job_script, hurry, uid, gid)
	slurm.log_info("%s: slurm_bb_job_teardown(). job id:%s, job script:%s, hurry:%s, uid:%s, gid:%s",
		lua_script_name, job_id, job_script, hurry, uid, gid)
	local rc, ret_str = sleep_wrapper(1)
	local tab = apiCall2(uid, "$stack_name", job_id) --user, cluster, project, jobid
	return rc, ret_str
end

--[[
--slurm_bb_setup
--
--This function is called asynchronously and is not required to return quickly.
--This function is called while the job is pending.
--]]
function slurm_bb_setup(job_id, uid, gid, pool, bb_size, job_script, job_info)
	slurm.log_info("%s: slurm_bb_setup(). job id:%s, uid: %s, gid:%s, pool:%s, size:%s, job script:%s",
		lua_script_name, job_id, uid, gid, pool, bb_size, job_script)

	return slurm.SUCCESS
end

--[[
--slurm_bb_data_in
--
--This function is called asynchronously and is not required to return quickly.
--This function is called immediately after slurm_bb_setup while the job is
--pending.
--]]
function slurm_bb_data_in(job_id, job_script, uid, gid, job_info)
	slurm.log_info("%s: slurm_bb_data_in(). job id:%s, job script:%s, uid:%s, gid:%s",
		lua_script_name, job_id, job_script, uid, gid)
	local rc, ret_str = sleep_wrapper(1)
        -- CALL API TO GET VARIABLE VALUES HERE
        -- save the values to file to pass them to the next function
        local tab = apiCall(uid, "$stack_name", job_info["account"], job_id)
        -- <state_save>/hash.<last_digit_job_id>/job.<job_id>/path
	job_id_len = string.len(job_id)
	last_hash_digit = string.sub(job_id, job_id_len, job_id_len)
	s3_file = "/var/spool/slurm.state/hash." .. last_hash_digit .. "/job." .. job_id .. "/s3"
        if (tab ~= nil)
        then
            slurm.log_info("tab is not nil, the local full URI is "..tab.LOCALHOST_AWS_CONTAINER_CREDENTIALS_FULL_URI)
            io.output(s3_file)
            io.write("AWS_CONTAINER_CREDENTIALS_FULL_URI="..tab.LOCALHOST_AWS_CONTAINER_CREDENTIALS_FULL_URI.."\n")
            io.write("AWS_CONTAINER_AUTHORIZATION_TOKEN="..tab.AWS_CONTAINER_AUTHORIZATION_TOKEN)
        end
	local file = io.open(s3_file, "rb") -- r read mode and b binary mode
        if not file then
		slurm.log_user("S3 file not found after first write.")
  		return rc, ret_str
	end
        local content = file:read "*a" -- *a or *all reads the whole file

        -- THIS VERIFIES THAT FOO=BAR is there
	slurm.log_info(content)
	file:close()
	return rc, ret_str
end

--[[
--slurm_bb_real_size
--
--This function is called asynchronously and is not required to return quickly.
--This function is called immediately after slurm_bb_data_in while the job is
--pending.
--
--This function is only called if pools are specified and the job requested a
--pool. This function may return a number (surrounded by quotes to make it a
--string) as the second return value. If it does, the job's usage of the pool
--will be changed to this number. A commented out example is given.
--]]
function slurm_bb_real_size(job_id, uid, gid, job_info)
	slurm.log_info("%s: slurm_bb_real_size(). job id:%s, uid:%s, gid:%s",
		lua_script_name, job_id, uid, gid)
	--return slurm.SUCCESS, "10000"
	return slurm.SUCCESS
end

--[[
--slurm_bb_paths
--
--WARNING: This function is called synchronously from slurmctld and must
--return quickly.
--This function is called after the job is scheduled but before the
--job starts running when the job is in a "running + configuring" state.
--
--The file specfied by path_file is an empty file. If environment variables are
--written to path_file, these environment variables are added to the job's
--environment. A commented out example is given.
--]]
function slurm_bb_paths(job_id, job_script, path_file, uid, gid, job_info)
	slurm.log_info("%s: slurm_bb_paths(). job id:%s, job script:%s, path file:%s, uid:%s, gid:%s",
		lua_script_name, job_id, job_script, path_file, uid, gid)

        -- <state_save>/hash.<last_digit_job_id>/job.<job_id>/path
        job_id_len = string.len(job_id)
        last_hash_digit = string.sub(job_id, job_id_len, job_id_len)
        s3_file = "/var/spool/slurm.state/hash." .. last_hash_digit .. "/job." .. job_id .. "/s3"
        local file = io.open(s3_file, "rb") -- r read mode and b binary mode
        if not file then
                slurm.log_user("S3 file not found in bb paths.")
                return slurm.SUCCESS
        end
        local content = file:read "*a" -- *a or *all reads the whole file

        -- THIS VERIFIES THAT FOO=BAR is there
        slurm.log_info(content)
        file:close()
	io.output(path_file)
	-- inject the two variables in user env
        io.write(content)
	return slurm.SUCCESS
end

--[[
--slurm_bb_pre_run
--
--This function is called asynchronously and is not required to return quickly.
--This function is called after the job is scheduled but before the
--job starts running when the job is in a "running + configuring" state.
--]]
function slurm_bb_pre_run(job_id, job_script, uid, gid, job_info)
	slurm.log_info("%s: slurm_bb_pre_run(). job id:%s, job script:%s, uid:%s, gid:%s",
		lua_script_name, job_id, job_script, uid, gid)
	local rc, ret_str
	rc, ret_str = sleep_wrapper(1)

	print_job_info(job_info)

	-- Generate a list of nodes allocated to the job.
	-- A hostlist expression of the nodes allocated to the job is in
	-- job_info["nodes"].
	-- scontrol show hostnames expands a hostlist expression to one node
	-- per line. It does not send an RPC to slurmctld.
	--[[
	local slurm_install_path = "/opt/slurm/install"
	local scontrol = string.format("%s/bin/scontrol show hostnames %s",
		slurm_install_path, job_info["nodes"])
	slurm.log_info("Running %s", scontrol)
	local fd = io.popen(scontrol)
	local nodelist = {}

	for node in fd:lines() do
		nodelist[#nodelist + 1] = node
	end
	fd:close()

	for i,v in ipairs(nodelist) do
		slurm.log_info("slurm_bb_pre_run: node(%u)=%s", i, v)
	end
	--]]

	return rc, ret_str
end

--[[
--slurm_bb_post_run
--
--This function is called asynchronously and is not required to return quickly.
--This function is called after the job finishes. The job is in a "stage out"
--state.
--]]
function slurm_bb_post_run(job_id, job_script, uid, gid, job_info)
	slurm.log_info("%s: slurm_post_run(). job id:%s, job script:%s, uid:%s, gid:%s",
		lua_script_name, job_id, job_script, uid, gid)
	local rc, ret_str = sleep_wrapper(1)
  	return rc, ret_str
end

--[[
--slurm_bb_data_out
--
--This function is called asynchronously and is not required to return quickly.
--This function is called after the job finishes immediately after
--slurm_bb_post_run. The job is in a "stage out" state.
--]]
function slurm_bb_data_out(job_id, job_script, uid, gid, job_info)
	slurm.log_info("%s: slurm_bb_data_out(). job id:%s, job script:%s, uid:%s, gid:%s",
		lua_script_name, job_id, job_script, uid, gid)
	local rc, ret_str = sleep_wrapper(1)
	return rc, ret_str
end

--[[
--slurm_bb_get_status
--
--This function is called asynchronously and is not required to return quickly.
--
--This function is called when "scontrol show bbstat" is run. It receives the
--authenticated user id and group id of the caller, as well as a variable
--number of arguments - whatever arguments are after "bbstat".
--For example:
--
--  scontrol show bbstat foo bar
--
--This command will pass 2 arguments after uid and gid to this function:
--  "foo" and "bar".
--
--If this function returns slurm.SUCCESS, then this function's second return
--value will be printed where the scontrol command was run. If this function
--returns slurm.ERROR, then this function's second return value is ignored and
--an error message will be printed instead.
--
--The example in this function simply prints the arguments that were given.
--]]
function slurm_bb_get_status(uid, gid, ...)

	local i, v, args
	slurm.log_info("%s: slurm_bb_get_status(), uid: %s, gid:%s",
		lua_script_name, uid, gid)

	-- Create a table from variable arg list
	args = {...}
	args.n = select("#", ...)

	for i,v in ipairs(args) do
		slurm.log_info("arg %u: \"%s\"", i, tostring(v))
	end

	return slurm.SUCCESS, "Status return message\n"
end

EOF

	chmod +x /opt/slurm/etc/task_prolog.sh
	luarocks install luasec
	systemctl restart slurmctld

}


# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 10.install.iam.headnode.sh: START" >&2
    installBBuffers
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 10.install.iam.headnode.sh: STOP" >&2
}

main "$@"