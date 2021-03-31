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

# This script configures an AWS Application Load Balancer (ALB) to disable a connection to an host
# where an Interactive Session was running.
# This script is meant to be used with DCV 2017 (and later) interactive sessions only.

# This script delete the Target Group containing the instance where the Session was running
# and delete the previously created Listener Rule.

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
    if [[ $# -lt 3 ]] ; then
        _help
        exit 0
    fi
    local -- _session_id=$1
    local -- _alb_host=$2
    local -- _alb_port=$3

    [ -z "${_session_id}" ] && _die "Missing input Session Id parameter."
    [ -z "${_alb_host}" ] && _die "Missing input ALB Host parameter."
    [ -z "${_alb_port}" ] && _die "Missing input ALB Port parameter."

    # check if AWS Cli is in the path
    aws help >/dev/null || _die "AWS Cli is not installed."

    # get ALB Amazon Resource Name (ARN) by dns-name
    local -- _alb_arn=$(aws elbv2 describe-load-balancers --query "LoadBalancers[? DNSName == '${_alb_host}'].LoadBalancerArn" --output text)
    [ -n "${_alb_arn}" ] || _die "Unable to get ALB identifier for the ALB (${_alb_host})."

    # get Listener arn
    local -- _listener_arn=$(aws elbv2 describe-listeners --load-balancer-arn "${_alb_arn}" \
        --query 'Listeners[? Port == `'${_alb_port}'`].ListenerArn' --output text)
    [ -n "${_listener_arn}" ] || _die "Listener for port (${_alb_port}) does not exist in the ALB (${_alb_host})."

    # get Target Group arn
    local -- _target_group_name=$(printf "%s" "${_session_id}" | tr -c 'a-zA-Z0-9' -)
    local -- _target_group_arn=$(aws elbv2 describe-target-groups --load-balancer-arn "${_alb_arn}" \
        --query "TargetGroups[? TargetGroupName == '${_target_group_name}'].TargetGroupArn" --output text)
    [ -n "${_target_group_arn}" ] || _die "Unable to get Target Group (${_target_group_name})"

    # get Rule arn
    local -- _rule_arn=$(aws elbv2 describe-rules --listener-arn "${_listener_arn}" \
        --query "Rules[? Actions[? TargetGroupArn == '${_target_group_arn}']].RuleArn" --output text)
    [ -n "${_rule_arn}" ] || _die "Unable to get Rule for Target Group (${_target_group_arn}) in the Listener (${_listener_arn})."

    # delete Rule
    aws elbv2 delete-rule --rule-arn "${_rule_arn}" >/dev/null
    [ $? -eq 0 ] || _die "Unable to delete Listener Rule (${_rule_arn})."

    # delete Target Group
    aws elbv2 delete-target-group --target-group-arn "${_target_group_arn}" >/dev/null
    [ $? -eq 0 ] || _die "Unable to delete Target Group (${_target_group_arn})."
}

# Check it's a DCV 2017 interactive session.
if [ "${INTERACTIVE_SESSION_REMOTE}" = "dcv2" ]; then
    main "${INTERACTIVE_SESSION_REMOTE_SESSION_ID}" "${ALB_PUBLIC_DNS_NAME}" "${ALB_PORT}"
fi

# ex:ts=4:sw=4:et:ft=sh: