#!/bin/bash

# Copyright 1999-2021 by Nice, srl.,
# Via Milliavacca, 9
# 14100 Asti - ITALY
# All rights reserved.
#
# This software is the confidential and proprietary information
# of Nice, srl. ("Confidential Information").
# You shall not disclose such Confidential Information
# and shall use it only in accordance with the terms of
# the license agreement you entered into with Nice.

# This script configures an AWS Application Load Balancer (ALB) to enable a connection to an host
# where an Interactive Session is running.
# This script is meant to be used with DCV 2017 (and later) interactive sessions only.

# This script creates a new Target Group containing the instance where the Session is running
# and add a new Listener Rule for the HTTPS listener of the ALB.

# The Listener Rule has the role to associate the input URL path to the Target Group. This path
# must be the web url path of the DCV server running on the execution node.
# Since it not possible to do URL path translation with ALB, every DCV server must have an unique
# web url path configured. It is suggested to use the hostname of the node as web url path
# for the DCV server running on that node.

# The maximum number of Listener Rule per ALB is 100, hence a single ALB can handle at maximum
# 100 Interactive Session running concurrently. To increase this limit, consider to add more ALB
# in the infrastructure.

# Prerequisites for:
#   EnginFrame node:
#     - AWS Command Line Interface (CLI) must be installed
#     - Since this script is going to be executed by the user running the EnginFrame Server, i.e. the Apache Tomcat user,
#       an AWS CLI profile must be configured for that user, having the permissions to list instances and to manage load balancers.
#       (see https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html)
#       Or alternatively, if EnginFrame is installed into an EC2 instance, configure the correct AWS role for this instance.
#
#   AWS account:
#     - AWS Application Load Balancer (ALB) and an HTTPS listener with a Default Target Group must be already configured and running.
#
#   DCV server node:
#     - configure each DCV server node with a unique web url path (see dcv.conf)

# Configuration parameters:

# ALB public DNS name
ALB_PUBLIC_DNS_NAME=
# ALB port
ALB_PORT=443
# AWS default region
export AWS_DEFAULT_REGION=

_die() {
    echo "ERROR: $@"
    exit 1
}

_help() {
    _cmd=$(basename "$0")
    echo "${_cmd}"
    echo "Usage:"
    echo "  ${_cmd} \"<session-id>\" \"<alb-host>\" \"<alb-port>\" \"<target-host>\" \"<target-port>\" \"<target-web-url-path>\""
    echo "  ${_cmd} \"tmp3569402005256372176\" \"alb-enginframe-xxx.eu-west-1.elb.amazonaws.com\" 443 \"10.0.0.10\" 8443 \"/dcv-server1\""
}

# Input parameters:
# - $1 session-id
# - $2 alb-host (alb public dnsname)
# - $3 alb-port
# - $4 target-host (private dnsname)
# - $5 target-port
# - $6 target-web-url-path (it must start with the "/" character)
main() {
    # parse input parameters
    if [[ $# -lt 6 ]] ; then
        _help
        exit 0
    fi
    local -- _session_id=$1
    local -- _alb_host=$2
    local -- _alb_port=$3
    local -- _instance_id=$4
    local -- _target_port=$5
    local -- _target_web_url_path=$6

    [ -z "${_session_id}" ] && _die "Missing input Session Id parameter."
    [ -z "${_alb_host}" ] && _die "Missing input ALB Host parameter."
    [ -z "${_alb_port}" ] && _die "Missing input ALB Port parameter."
    [ -z "${_instance_id}" ] && _die "Missing input InstanceID."
    [ -z "${_target_port}" ] && _die "Missing input Target Port parameter."
    [ -z "${_target_web_url_path}" ] && _die "Missing input Target Web Url Path parameter."

    # check if AWS Cli is in the path
    aws help >/dev/null || _die "AWS Cli is not installed."

    # get ALB Amazon Resource Name (ARN) by dns-name
    local -- _alb_arn=$(aws elbv2 describe-load-balancers --query "LoadBalancers[? DNSName == '${_alb_host}'].LoadBalancerArn" --output text)
    [ -n "${_alb_arn}" ] || _die "Unable to get ALB identifier for the ALB (${_alb_host})."

    # detect VPC of the ALB
    local -- _vpc_id=$(aws elbv2 describe-load-balancers --load-balancer-arns "${_alb_arn}" \
        --query "LoadBalancers[].VpcId" --output text)
    [ -n "${_vpc_id}" ] || _die "Unable to detect VPC of the ALB (${_alb_host})."

    # check if Listener exist
    local -- _listener_arn=$(aws elbv2 describe-listeners --load-balancer-arn "${_alb_arn}" \
        --query 'Listeners[? Port == `'${_alb_port}'`].ListenerArn' --output text)
    [ -n "${_listener_arn}" ] || _die "Listener for port (${_alb_port}) does not exist in the ALB (${_alb_host})."

    # check if Target Group for the given session already exists
    local -- _target_group_name=$(printf "%s" "${_session_id}" | tr -c 'a-zA-Z0-9' -)
    local -- _target_group_arn=$(aws elbv2 describe-target-groups --load-balancer-arn "${_alb_arn}" \
        --query "TargetGroups[? TargetGroupName == '${_target_group_name}'].TargetGroupArn" --output text)
    if [ -z "${_target_group_arn}" ]; then

        # create new target group for the given instance (Healty Check 404 is expected from the DCV Server)
        _target_group_arn=$(aws elbv2 create-target-group --name "${_target_group_name}" --protocol HTTPS --port "${_target_port}" --matcher "HttpCode=404" --vpc-id "${_vpc_id}" \
        --query "TargetGroups[0].TargetGroupArn" --output text)
        [ -n "${_target_group_arn}" ] || _die "Unable to create Target Group (${_target_group_name}) in the VPC (${_vpc_id})"

        # enable sticky session
        #aws elbv2 modify-target-group-attributes --target-group-arn "${_target_group_arn}" --attributes "Key=stickiness.enabled,Value=true" >/dev/null
        #[ $? -eq 0 ] || _die "Unable to set sticky session for the Target Group (${_target_group_arn})."

        # register instance in the new target group
        aws elbv2 register-targets --target-group-arn "${_target_group_arn}" --targets "Id=${_instance_id}" >/dev/null
        [ $? -eq 0 ] || _die "Unable to register Instance (${_instance_id}) in the Target Group (${_target_group_arn})."

        # get current max priority
        local -- _current_priority=$(aws elbv2 describe-rules --listener-arn "${_listener_arn}" \
        --query "max(Rules[? Priority != 'default'].Priority.to_number(@))" --output text)
        [ -n "${_current_priority}" ] || _current_priority=0

        # add target rule to the selected listener
        local -- _priority=$((_current_priority+1))
        local -- _target_path="${_target_web_url_path}*"

        local -- _rule_arn=$(aws elbv2 create-rule --listener-arn "${_listener_arn}" --priority "${_priority}" \
        --conditions Field=path-pattern,Values="${_target_path}" --actions Type=forward,TargetGroupArn=${_target_group_arn} \
        --query "Rules[0].RuleArn" --output text)
        [ -n "${_rule_arn}" ] || _die "Unable to create Rule for the Listener (${_listener_arn}), Target Group (${_target_group_arn}) and target path (${_target_path})."
    fi
    
    #avoid 404 ALB error
    sleep 10

    # set output variables
    export INTERACTIVE_SESSION_TARGET_HOST="${_alb_host}"
    export INTERACTIVE_SESSION_TARGET_PORT="${_alb_port}"
    export INTERACTIVE_SESSION_TARGET_WEBURLPATH="${_target_web_url_path}"
}

# Check it's a DCV 2017 interactive session.
if [ "${INTERACTIVE_SESSION_REMOTE}" = "dcv2" ]; then
    main "${INTERACTIVE_SESSION_REMOTE_SESSION_ID}" "${ALB_PUBLIC_DNS_NAME}" "${ALB_PORT}" "${INTERACTIVE_SESSION_DCV2_WEBURLPATH:1}" "${INTERACTIVE_DEFAULT_DCV2_WEB_PORT}" "${INTERACTIVE_SESSION_DCV2_WEBURLPATH}"
fi

# ex:ts=4:sw=4:et:ft=sh: