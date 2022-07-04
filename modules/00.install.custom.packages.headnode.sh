#!/bin/bash
set -e

amazon-linux-extras enable python3.8
yum install -y python38 python38-devel tmux htop glances