#!/bin/bash
set -x
set -e

installRAID0() {
    parted -a optimal /dev/nvme1n1 --script mklabel gpt
    parted -a optimal /dev/nvme2n1 --script mklabel gpt
    parted -a optimal /dev/nvme3n1 --script mklabel gpt
    parted -a optimal /dev/nvme4n1 --script mklabel gpt
    parted -a optimal /dev/nvme5n1 --script mklabel gpt
    parted -a optimal /dev/nvme6n1 --script mklabel gpt
    parted -a optimal /dev/nvme7n1 --script mklabel gpt
    parted -a optimal /dev/nvme8n1 --script mklabel gpt
    mkfs.btrfs -d raid0 -m raid0 -f /dev/nvme[1-8]n1
    uuid=$(blkid /dev/nvme1n1 -o value -s UUID)
    sudo sed -i s/btrfs/d /etc/fstab
    echo "UUID=$uuid /scratch           btrfs   defaults      0  0" >> /etc/fstab
    mkdir -p /scratch
    mount /scratch
    chmod -R 777 /scratch

    sudo sed -i s/defaults,_netdev,flock,user_xattr,noatime,noauto,x-systemd.automount/defaults,noatime,flock,_netdev,x-systemd.automount,x-systemd.requires=network.service/g /etc/fstab

    sysctl -w fs.file-max=262144
}

# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 20.make.raid0.nvme.sh: START" >&2
    installRAID0
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 20.make.raid0.nvme.sh: STOP" >&2
}

main "$@"
