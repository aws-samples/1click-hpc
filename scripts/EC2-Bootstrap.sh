#!/bin/bash

#bootstrap already executed
if [[ -f /home/ec2-user/bootstrap.log ]]; then
    exit 1
fi

set -x
exec >/home/ec2-user/bootstrap.log; exec 2>&1

sudo yum -y -q install jq sssd realmd oddjob oddjob-mkhomedir adcli samba-common samba-common-tools krb5-workstation openldap-clients policycoreutils-python
sudo chown -R ec2-user:ec2-user /home/ec2-user/
#source cluster profile and move to the home dir
cd /home/ec2-user

. cluster_env

#install Lustre client
sudo amazon-linux-extras install -y lustre2.10 > /dev/null 2>&1

python3 -m pip install "aws-parallelcluster" --upgrade --user --quiet
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash
chmod ug+x ~/.nvm/nvm.sh
source ~/.nvm/nvm.sh > /dev/null 2>&1
nvm install --lts=Fermium > /dev/null 2>&1
node --version

if [[ $FSX_ID == "AUTO" ]];then
FSX=$(cat <<EOF
  - MountDir: /fsx
    Name: new
    StorageType: FsxLustre
    FsxLustreSettings:
      StorageCapacity: 1200
      DeploymentType: SCRATCH_2
      ImportedFileChunkSize: 1024
      DataCompressionType: LZ4
      ExportPath: s3://${S3_BUCKET}
      ImportPath: s3://${S3_BUCKET}
      AutoImportPolicy: NEW_CHANGED
EOF
)
else
FSX=$(cat <<EOF
  - MountDir: /fsx
    Name: existing
    StorageType: FsxLustre
    FsxLustreSettings:
      FileSystemId: ${FSX_ID}
EOF
)
fi
export FSX

## Download from internet and Uplaod the needed packages on S3
wget -nv https://dn3uclhgxk1jt.cloudfront.net/enginframe/packages/enginframe-latest.jar
wget -nv https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.28/mysql-connector-java-8.0.28.jar
wget -nv https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-el7-x86_64.tgz

aws s3 cp --quiet enginframe-latest.jar s3://${S3_BUCKET}/packages/
aws s3 cp --quiet mysql-connector-java-8.0.28.jar s3://${S3_BUCKET}/packages/
aws s3 cp --quiet nice-dcv-el7-x86_64.tgz s3://${S3_BUCKET}/packages/

export SECRET_ARN=$(aws secretsmanager describe-secret --secret-id "hpc-1click-${CLUSTER_NAME}" --query ARN --output text --region "${AWS_REGION_NAME}")

/usr/bin/envsubst < "1click-hpc/parallelcluster/config.${AWS_REGION_NAME}.sample.yaml" > config.${AWS_REGION_NAME}.yaml
/usr/bin/envsubst '${SLURM_DB_ENDPOINT}' < "1click-hpc/enginframe/efinstall.config" > efinstall.config
/usr/bin/envsubst '${S3_BUCKET}' < "1click-hpc/enginframe/fm.browse.ui" > fm.browse.ui

aws s3 cp --quiet efinstall.config "s3://${S3_BUCKET}/1click-hpc/enginframe/efinstall.config" --region "${AWS_REGION_NAME}"
aws s3 cp --quiet fm.browse.ui "s3://${S3_BUCKET}/1click-hpc/enginframe/fm.browse.ui" --region "${AWS_REGION_NAME}"
rm -f fm.browse.ui efinstall.config

#Create the key pair (remove the existing one if it has the same name)
aws ec2 create-key-pair --key-name ${KEY_PAIR} --query KeyMaterial --output text > /home/ec2-user/.ssh/id_rsa
if [ $? -ne 0 ]; then
    aws ec2 delete-key-pair --key-name ${KEY_PAIR}
    aws ec2 create-key-pair --key-name ${KEY_PAIR} --query KeyMaterial --output text > /home/ec2-user/.ssh/id_rsa
fi
sudo chmod 400 /home/ec2-user/.ssh/id_rsa

#Create the cluster and wait
/home/ec2-user/.local/bin/pcluster create-cluster --cluster-name "hpc-1click-${CLUSTER_NAME}" --cluster-configuration config.${AWS_REGION_NAME}.yaml --rollback-on-failure false --wait

HEADNODE_PRIVATE_IP=$(/home/ec2-user/.local/bin/pcluster describe-cluster --cluster-name "hpc-1click-${CLUSTER_NAME}" | jq -r '.headNode.privateIpAddress')
echo "export HEADNODE_PRIVATE_IP='${HEADNODE_PRIVATE_IP}'" >> cluster_env

# send SUCCESFUL to the wait handle
curl -X PUT -H 'Content-Type:' \
    --data-binary "{\"Status\" : \"SUCCESS\",\"Reason\" : \"Configuration Complete\",\"UniqueId\" : \"$HEADNODE_PRIVATE_IP\",\"Data\" : \"$HEADNODE_PRIVATE_IP\"}" \
    "${WAIT_HANDLE}"