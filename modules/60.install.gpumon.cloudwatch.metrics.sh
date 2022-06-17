#!/bin/bash
set -e

yum install -y git amazon-linux-extras
amazon-linux-extras enable python3.8

git clone https://github.com/Stability-AI/gpumon-service-for-cloudwatch.git

yum install -y python3.8 python3-distutils
python3.8 -m pip install -r gpumon-service-for-cloudwatch/requirements.txt

mv gpumon-service-for-cloudwatch/gpumon.py /etc/gpumon.py
mv gpumon-service-for-cloudwatch/gpumon.service /etc/systemd/system/gpumon.service

systemctl enable --now gpumon
