#!/bin/bash

# actions necessary post first headnode reboot
# run as root

# establish disk quota
xfs_quota -x -c 'limit -u bsoft=30000m bhard=40000m -d' /

# index /home and /fsx
duc index /home
duc index /fsx

