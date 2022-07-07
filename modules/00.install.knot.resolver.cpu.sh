#!/bin/bash
set -e

amazon-linux-extras install epel -y
yum install -y knot-resolver knot-utils
systemctl enable --now kresd@{1..2}.service
