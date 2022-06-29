#!/bin/bash
set -e

# Override run_instance attributes
# Name of the group is still hardcoded, need a way to get variable from cloudformation here
cat > /lib/udev/rules.d/71-nvidia.rules<< EOF
# Load and unload nvidia-uvm module
ACTION=="add", DEVPATH=="/bus/pci/drivers/nvidia", RUN+="/sbin/modprobe nvidia-uvm"
ACTION=="remove", DEVPATH=="/bus/pci/drivers/nvidia", RUN+="/sbin/modprobe -r nvidia-uvm"

# This will create the device nvidia device nodes
ACTION=="add", DEVPATH=="/bus/pci/drivers/nvidia", RUN+="/usr/bin/nvidia-smi"

# Create the device node for the nvidia-uvm module
ACTION=="add", DEVPATH=="/module/nvidia_uvm", SUBSYSTEM=="module", RUN+="/sbin/create-uvm-dev-node"
EOF