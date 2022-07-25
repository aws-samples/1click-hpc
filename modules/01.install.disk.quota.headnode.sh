#!/bin/bash
set -e

installQuota{
    sed -i 's/defaults,noatime/defaults,noatime,uquota,gquota,pquota/' /etc/fstab
    sed -i '0,/"$/s// rootflags=uquota,gquota,pquota"/' /etc/default/grub
    cp /boot/grub2/grub.cfg /boot/grub2/grub.cfg.orig
    grub2-mkconfig -o /boot/grub2/grub.cfg

    # manually reboot the headnode and then make default quotas like
    # xfs_quota -x -c 'limit -u bsoft=30000m bhard=40000m -d' /
}

changeNice{
    # default niceness
    echo "@hpc-cluster-users soft priority 10" >> /etc/security/limits.conf
}


# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 01.install.disk.quota.headnode.sh: START" >&2
    installQuota
    changeNice
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 01.install.disk.quota.headnode.sh: STOP" >&2
}

main "$@"