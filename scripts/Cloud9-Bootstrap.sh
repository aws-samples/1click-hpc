#!/bin/bash

set -x
exec >/tmp/bootstrap.log; exec 2>&1

#source user profile and move to the home dir
. /home/ec2-user/.bashrc
cd /home/ec2-user/environment

#install AWS ParallelCluster
pip install --user -U boto boto3 botocore awscli aws-sam-cli aws-parallelcluster

#Create the key pair (remove the existing one if it has the same name)
aws ec2 create-key-pair --key-name ${KEY_PAIR} --query KeyMaterial --output text > /home/ec2-user/.ssh/id_rsa
if [ $? -ne 0 ]; then
    aws ec2 delete-key-pair --key-name ${KEY_PAIR}
    aws ec2 create-key-pair --key-name ${KEY_PAIR} --query KeyMaterial --output text > /home/ec2-user/.ssh/id_rsa
fi
sudo chmod 400 /home/ec2-user/.ssh/id_rsa

#download the AWS ParallelCluster configuration file and substitute env varaible.
wget https://raw.githubusercontent.com/aws-samples/aws-pcluster-post-samples/development/parallelcluster/${PC_CONFIG}
/usr/bin/envsubst < ${PC_CONFIG} > cluster.config
sudo chown -R ec2-user:ec2-user /home/ec2-user/
rm ${PC_CONFIG}

#Create the cluster
/home/ec2-user/.local/bin/pcluster create -c cluster.config ${CLUSTER_NAME} --norollback
MASTER_PUBLIC_IP=$(/home/ec2-user/.local/bin/pcluster status ${CLUSTER_NAME} | grep MasterPublicIP | sed 's/MasterPublicIP: //')
echo "export MASTER_PUBLIC_IP='${MASTER_PUBLIC_IP}'" >> /home/ec2-user/.bashrc

# Modify the Message Of The Day
sudo rm -f /etc/update-motd.d/*
sudo wget https://raw.githubusercontent.com/aws-samples/aws-pcluster-post-samples/development/scripts/motd -O /etc/update-motd.d/10-HPC
sudo chmod +x /etc/update-motd.d/10-HPC
echo 'run-parts /etc/update-motd.d' >> /home/ec2-user/.bash_profile

#attach the ParallelCluster SG to the Cloud9 instance (for FSx or NFS)
INSTANCE_ID=$(curl http://169.254.169.254/latest/meta-data/instance-id)
SG_CLOUD9=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query Reservations[*].Instances[*].SecurityGroups[*].GroupId --output text)
SG_MASTER=$(aws cloudformation describe-stack-resources --stack-name parallelcluster-$CLUSTER_NAME --logical-resource-id ComputeSecurityGroup --query "StackResources[*].PhysicalResourceId" --output text)
aws ec2 modify-instance-attribute --instance-id $INSTANCE_ID --groups $SG_CLOUD9 $SG_MASTER

if grep -q "^fsx_settings" "cluster.config"; then

  #install Lustre client
  sudo yum -y install lustre-client
  
  #mount the same FSx created for the HPC Cluster
  mkdir fsx
  FSX_STACK_NAME=$(aws cloudformation describe-stack-resources --stack-name parallelcluster-$CLUSTER_NAME --logical-resource-id FSXSubstack --query "StackResources[*].PhysicalResourceId" --output text)
  FSX_ID=$(aws cloudformation describe-stacks --stack-name $FSX_STACK_NAME --query "Stacks[*].Outputs[*].OutputValue" --output text)
  FSX_DNS_NAME=$(aws fsx describe-file-systems --file-system-ids $FSX_ID --query "FileSystems[*].DNSName" --output text)
  FSX_MOUNT_NAME=$(aws fsx describe-file-systems --file-system-ids $FSX_ID  --query "FileSystems[*].LustreConfiguration.MountName" --output text)
  sudo mount -t lustre -o noatime,flock $FSX_DNS_NAME@tcp:/$FSX_MOUNT_NAME fsx
  sudo bash -c "echo \"$FSX_DNS_NAME@tcp:/$FSX_MOUNT_NAME /home/ec2-user/environment/fsx lustre defaults,noatime,flock,_netdev 0 0\" >> /etc/fstab"
else
  mkdir nfs
  MASTER_PRIVATE_IP=$(/home/ec2-user/.local/bin/pcluster status ${CLUSTER_NAME} | grep MasterPrivateIP | sed 's/MasterPrivateIP: //'    )
  SHARED_DIR=$(cat /home/ec2-user/environment/cluster.config | grep shared_dir | awk '{print $3}')
  sudo mount -t nfs -o hard,intr,noatime,_netdev $MASTER_PRIVATE_IP:$SHARED_DIR /home/ec2-user/environment/nfs
  sudo bash -c "echo \"$MASTER_PRIVATE_IP:$SHARED_DIR /home/ec2-user/environment/nfs nfs hard,intr,noatime,_netdev 0 0\" >> /etc/fstab"
fi

# send SUCCESFUL to the wait handle
curl -X PUT -H 'Content-Type:' \
    --data-binary "{\"Status\" : \"SUCCESS\",\"Reason\" : \"Configuration Complete\",\"UniqueId\" : \"$MASTER_PUBLIC_IP\",\"Data\" : \"$MASTER_PUBLIC_IP\"}" \
    "${WAIT_HANDLE}"