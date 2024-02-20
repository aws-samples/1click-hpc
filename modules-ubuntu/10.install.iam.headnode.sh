#!/bin/bash

# depends on 03.configure.slurm.acct.headnode.sh
set -x
set -e
source '/etc/parallelcluster/cfnconfig'

installBBuffers() {
    export APIURL="$(aws secretsmanager get-secret-value --secret-id "IamApiprod-IamApiUrlSecret" --query SecretString --output text --region us-west-2 --cli-connect-timeout 1)" #todo: do not hardcode, add secret name as CF parameter
    export APISECRET="$(aws secretsmanager get-secret-value --secret-id "IamApiprod-HeadNodeSecret" --query SecretString --output text --region us-west-2 --cli-connect-timeout 1)" #todo: do not hardcode, add secret name as CF parameter

    echo " " >> /opt/slurm/etc/slurm.conf
    echo "#BURST BUFFER CONFIGURATION" >> /opt/slurm/etc/slurm.conf
    echo "BurstBufferType=burst_buffer/lua" >> /opt/slurm/etc/slurm.conf
    echo "DebugFlags=Power,BurstBuffer" >> /opt/slurm/etc/slurm.conf

    echo " " >> /opt/slurm/etc/slurm.conf
    echo "#TASK PROLOG CONFIGURATION" >> /opt/slurm/etc/slurm.conf
    echo "TaskProlog=/opt/slurm/etc/task_prolog.sh" >> /opt/slurm/etc/slurm.conf

	#activate burst buffers with job_submit.lua
	sed -i '/^\s*stability_cluster.*/a\    if job_desc.user_name ~= "root" then\n        job_desc.burst_buffer = "#BB_LUA"\n    end' "/opt/slurm/etc/job_submit.lua"

cat > /opt/slurm/etc/task_prolog.sh << EOF
#!/bin/bash
host=\$(hostname | sed -e "s/-dy-//" | sed -e "s/-//g" | sed -e "s/large//")
cluster=\$(echo \$SLURM_WORKING_CLUSTER | cut -d':' -f1 | sed -e "s/^hpc-1click-//" | sed -e "s/^stability-//")
if [[ "\${AWS_CONTAINER_CREDENTIALS_FULL_URI}" != *"roleSessionName"* ]];then
    echo "export AWS_CONTAINER_CREDENTIALS_FULL_URI=\${AWS_CONTAINER_CREDENTIALS_FULL_URI}?roleSessionName=\${SLURM_JOB_ACCOUNT}-\${cluster}-\${USER}-\${host}"
fi

if [ "\${SLURM_JOB_USER}" == "smchosting" ]; then
  exit 0
fi

if command -v /usr/sbin/sshd >/dev/null; then
  sshport=\$((22000 + \${SLURM_JOB_ID}%1000))
  if ! pgrep -f "sshd -D -p \${sshport}" &> /dev/null 2>&1;then
      #SSHPATH=/scratch/customsshd.\${SLURM_JOB_ID}
      SSHPATH=\$(mktemp -d -t customsshd.XXXXXX)
      if [ ! -d \${SSHPATH} ];then
          mkdir -p \${SSHPATH}
      fi
      if [ ! -f \${SSHPATH}/ssh_host_rsa_key ];then
          ssh-keygen -f \${SSHPATH}/ssh_host_rsa_key -N '' -t rsa
      fi

      if [ ! -f \${SSHPATH}/ssh_host_dsa_key ];then
          ssh-keygen -f \${SSHPATH}/ssh_host_dsa_key -N '' -t dsa
      fi
      if [ ! -f \${SSHPATH}/sshd_config ];then
      cat > \${SSHPATH}/sshd_config << INEOF
HostKey \${SSHPATH}/ssh_host_rsa_key
HostKey \${SSHPATH}/ssh_host_dsa_key
AuthorizedKeysFile  \${HOME}/.ssh/authorized_keys
ChallengeResponseAuthentication no
PasswordAuthentication no
AuthorizedKeysCommand /usr/bin/sss_ssh_authorizedkeys
AuthorizedKeysCommandUser \${SLURM_JOB_USER}
AllowUsers \${SLURM_JOB_USER}
UsePAM no
Subsystem   sftp    /usr/lib/ssh/sftp-server
PidFile \${SSHPATH}/sshd.pid
INEOF
      fi
      mkdir -p /tmp/\${SLURM_JOB_USER}
      memcached -p /tmp/\${SLURM_JOB_USER}/memcached.sock -d
      /usr/sbin/sshd -p \${sshport} -f \${SSHPATH}/sshd_config -o "SetEnv=AWS_CONTAINER_CREDENTIALS_FULL_URI=\${AWS_CONTAINER_CREDENTIALS_FULL_URI}?roleSessionName=\${SLURM_JOB_ACCOUNT}-\${cluster}-\${SLURM_JOB_USER}-\${host} AWS_CONTAINER_AUTHORIZATION_TOKEN=\${AWS_CONTAINER_AUTHORIZATION_TOKEN}"
  fi
fi
EOF

cat > /opt/slurm/sbin/stablessh << EOF
#!/bin/bash

# Check if a list of params contains a specific param
# usage: if _param_variant "h|?|help t|tunnel j|jobid" ; then ...
# the global variable \$key is updated to the long notation (last entry in the pipe delineated list, if applicable)
_param_variant() {
  for param in \$1 ; do
    local variants=\${param//\|/ }
    for variant in \$variants ; do
      if [[ "\$variant" = "\$2" ]] ; then
        # Update the key to match the long version
        local arr=(\${param//\|/ })
        let last=\${#arr[@]}-1
        key="\${arr[\$last]}"
        return 0
      fi
    done
  done
  return 1
}

# Get input parameters in short or long notation, with no dependencies beyond bash
# usage:
#     # First, set your defaults
#     param_help=false
#     param_path="."
#     param_file=false
#     param_image=false
#     param_image_lossy=true
#     # Define allowed parameters
#     allowed_params="h|?|help t|tunnel j|jobid"
#     # Get parameters from the arguments provided
#     _get_params \$*
#
# Parameters will be converted into safe variable names like:
#     param_help,
#     param_tunnel,
#     param_jobid,
#
# Parameters without a value like "-h" or "--help" will be treated as
# boolean, and will be set as param_help=true
#
# Parameters can accept values in the various typical ways:
#     -i "path/goes/here"
#     --image "path/goes/here"
#     --image="path/goes/here"
#     --image=path/goes/here
# These would all result in effectively the same thing:
#     param_image="path/goes/here"
#
# Concatinated short parameters (boolean) are also supported
#     -vhm is the same as -v -h -m
_get_params(){

  local param_pair
  local key
  local value
  local shift_count

  while : ; do
    # Ensure we have a valid param. Allows this to work even in -u mode.
    if [[ \$# == 0 || -z \$1 ]] ; then
      break
    fi

    # Split the argument if it contains "="
    param_pair=(\${1//=/ })
    # Remove preceeding dashes
    key="\${param_pair[0]#--}"

    # Check for concatinated boolean short parameters.
    local nodash="\${key#-}"
    local breakout=false
    if [[ "\$nodash" != "\$key" && \${#nodash} -gt 1 ]]; then
      # Extrapolate multiple boolean keys in single dash notation. ie. "-vmh" should translate to: "-v -m -h"
      local short_param_count=\${#nodash}
      let new_arg_count=\$#+\$short_param_count-1
      local new_args=""
      # \$str_pos is the current position in the short param string \$nodash
      for (( str_pos=0; str_pos<new_arg_count; str_pos++ )); do
        # The first character becomes the current key
        if [ \$str_pos -eq 0 ] ; then
          key="\${nodash:\$str_pos:1}"
          breakout=true
        fi
        # \$arg_pos is the current position in the constructed arguments list
        let arg_pos=\$str_pos+1
        if [ \$arg_pos -gt \$short_param_count ] ; then
          # handle other arguments
          let orignal_arg_number=\$arg_pos-\$short_param_count+1
          local new_arg="\${!orignal_arg_number}"
        else
          # break out our one argument into new ones
          local new_arg="-\${nodash:\$str_pos:1}"
        fi
        new_args="\$new_args \"\$new_arg\""
      done
      # remove the preceding space and set the new arguments
      eval set -- "\${new_args# }"
    fi
    if ! \$breakout ; then
      key="\$nodash"
    fi

    # By default we expect to shift one argument at a time
    shift_count=1
    if [ "\${#param_pair[@]}" -gt "1" ] ; then
      # This is a param with equals notation
      value="\${param_pair[1]}"
    else
      # This is either a boolean param and there is no value,
      # or the value is the next command line argument
      # Assume the value is a boolean true, unless the next argument is found to be a value.
      value=true
      if [[ \$# -gt 1 && -n "\$2" ]]; then
        local nodash="\${2#-}"
        if [ "\$nodash" = "\$2" ]; then
          # The next argument has NO preceding dash so it is a value
          value="\$2"
          shift_count=2
        fi
      fi
    fi

    # Check that the param being passed is one of the allowed params
    if _param_variant "\$allowed_params" "\$key" ; then
      # --key-name will now become param_key_name
      eval param_\${key//-/_}="\$value"
    else
      printf 'WARNING: Unknown option (ignored): %s\n' "\$1" >&2
    fi
    shift \$shift_count
  done
}

function _usage()
{
  ###### U S A G E : Help and ERROR ######
  cat <<INEOF
  stablessh \$Options
  \$*
          Usage: stablessh <[options]>
          Options:
                  -h -?  --help         Show this message
                  -t     --tunnel       Show the ssh config entry to build the vscode debugging tunnel
                  -j     --jobid        Your slurm job ID (other user's jobs will not work)

          Example: stablessh -t -j 123456
INEOF
}

function _tunnel()
{
  ###### T U N N E L : ssh config entry ######
cat <<INEOF
#  To connect to your job, add this in your home computer ssh config file:
#  (possible at ~/.ssh/config, you also need to edit your private key below)

# you can save this part permanently in your ~/.ssh/config file
# ==========================permanent==========================
Host sai-*
    IdentityFile ~/.ssh/<privkey>
    ServerAliveInterval 240
    ServerAliveCountMax 10
    TCPKeepAlive yes
    UseKeychain yes
# for mac users, UseKeychain will save your password in the keychain
# replace the <privkey> above with your home computer cluster private key

Host sai-jumphost-int
    HostName westint1.hpc.stability.ai
    User \$USER
    Port 22
# ==========================end permanent==========================

# please modify the following for any new job or add more entries if you run multiple jobs
Host sai-vscode-direct
    Hostname \$1
    User \$USER
    Port \$2
    ProxyJump jumphost-int
    UserKnownHostsFile=/dev/null
    StrictHostKeyChecking no
# make sure to match the proxyjump host name with the name of the second entry above
INEOF
}

# Assign defaults for parameters
param_help=false
param_jobid=0
param_tunnel=false

# Define the params we will allow
allowed_params="h|?|help t|tunnel j|jobid"

# Get the params from arguments provided
_get_params \$*

# takes the job id as an argument and established a ssh connection inside the user job cgroup
# it works with launching a sshd process within the slurm job via slurm prolog

if [ "\$param_jobid" == "0" ];then
    _usage
    exit 1
fi

if [ "\$param_help" == "true" ];then
    _usage
    exit 1
fi

# get the main host and calculate the ssh port from the job id
mainhost=\$(scontrol show hostnames \$(scontrol show job \$param_jobid | grep '^   NodeList' | cut -d "=" -f2) | head -n 1)
sshport=\$((22000 + \$param_jobid%1000))

if [ "\$mainhost" == "" ];then
    echo "please check again your valid job IDs by running \"squeue --me\""
    exit 1
fi

if [[ "\$param_tunnel" == "true" ]];then
    _tunnel \$mainhost \$sshport
else
    ssh -p \$sshport -o "UserKnownHostsFile=/dev/null" \$mainhost
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
	#add stablessh command on all nodes
	chmod +x /opt/slurm/sbin/stablessh
  ln -s /opt/slurm/sbin/stablessh /usr/local/bin/stablessh

}


# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 10.install.iam.headnode.sh: START" >&2
    installBBuffers
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 10.install.iam.headnode.sh: STOP" >&2
}

main "$@"
