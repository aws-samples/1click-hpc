#!/bin/bash

source /etc/profile

update=0
tag_userid=""
tag_jobid=""
tag_project=""

if [ ! -f /root/jobs/jobs_users ] || [ ! -f /root/jobs/jobs_ids ]; then
    exit 0
fi

active_users=$(cat /root/jobs/jobs_users | sort | uniq )
active_jobs=$(cat /root/jobs/jobs_ids | sort )
echo $active_users > /root/jobs/tmp_jobs_users
echo $active_jobs > /root/jobs/tmp_jobs_ids

if [ -f /root/jobs/jobs_projects ]; then
    active_projects=$(cat /root/jobs/jobs_projects | sort | uniq )
    echo $active_projects > /root/jobs/tmp_jobs_projects
fi

if [ ! -f /root/jobs/tag_userid ] || [ ! -f /root/jobs/tag_jobid ]; then
    echo $active_users > /root/jobs/tag_userid
    echo $active_jobs > /root/jobs/tag_jobid
    echo $active_projects > /root/jobs/tag_project
    update=1
else
    active_users=$(cat /root/jobs/tmp_jobs_users)
    active_jobs=$(cat /root/jobs/tmp_jobs_ids)
    if [ -f /root/jobs/tmp_jobs_projects ]; then
        active_projects=$(cat /root/jobs/tmp_jobs_projects)
    fi 
    tag_userid=$(cat /root/jobs/tag_userid)
    tag_jobid=$(cat /root/jobs/tag_jobid)
    if [ -f /root/jobs/tag_project ]; then
        tag_project=$(cat /root/jobs/tag_project)
    fi

    if [ "${active_users}" != "${tag_userid}" ]; then
        tag_userid="${active_users}"
        echo ${tag_userid} > /root/jobs/tag_userid
        update=1
    fi

    if [ "${active_jobs}" != "${tag_jobid}" ]; then
        tag_jobid="${active_jobs}"
        echo ${tag_jobid} > /root/jobs/tag_jobid
        update=1
    fi

    if [ "${active_projects}" != "${tag_project}" ]; then
        tag_project="${active_projects}"
        echo ${tag_project} > /root/jobs/tag_project
        update=1
    fi
fi

if [ ${update} -eq 1 ]; then
    # Instance ID
    tag_userid=$(cat /root/jobs/tag_userid)
    tag_jobid=$(cat /root/jobs/tag_jobid)
    tag_project=$(cat /root/jobs/tag_project)
    #use datadog host tags API here
    sleep $[ ( $RANDOM % 30 ) + 1 ]s
    TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
    instance=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/instance-id)
    curl -X PUT "https://api.datadoghq.com/api/v1/tags/hosts/${instance}" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -H "DD-API-KEY: <replacewithyourkey>" \
    -H "DD-APPLICATION-KEY: <replacewithyourkey>" \
    -d @- << EOF
{
  "host": "${instance}",
  "tags": [
    "hpcuser:${tag_userid}",
    "slurmjob:${tag_jobid}",
    "project:${tag_project}",
    "region:us-east-1",
    "availability-zone:sagemaker"
  ]
}
EOF

fi