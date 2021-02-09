#!/bin/bash

set -x
exec >/tmp/bootstrap.log; exec 2>&1
. /home/ec2-user/.bashrc
date
cd /home/ec2-user/environment
sudo yum -y install jq
pip install --user -U boto boto3 botocore awscli aws-sam-cli aws-parallelcluster
aws ec2 create-key-pair --key-name ${KEY_PAIR} --query KeyMaterial --output text > /home/ec2-user/.ssh/id_rsa
chown 644 /home/ec2-user/.ssh/id_rsa
wget https://raw.githubusercontent.com/aws-samples/aws-pcluster-post-samples/development/parallelcluster/config.sample
/usr/bin/envsubst < config.sample > cluster.config
sudo chown -R ec2-user:ec2-user /home/ec2-user/
/home/ec2-user/.local/bin/pcluster create -c cluster.config ${CLUSTER_NAME} --norollback
export MASTER_IP=$(/home/ec2-user/.local/bin/pcluster status ${CLUSTER_NAME} | grep MasterPublicIP | sed 's/MasterPublicIP: //')

curl -X PUT -H 'Content-Type:' \
    --data-binary "{\"Status\" : \"SUCCESS\",\"Reason\" : \"Configuration Complete\",\"UniqueId\" : \"$MASTER_IP\",\"Data\" : \"$MASTER_IP\"}" \
    "${WAIT_HANDLE}"