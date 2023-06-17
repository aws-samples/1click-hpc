#!/bin/bash
set -x
set -e

source "/etc/parallelcluster/cfnconfig"

installQuota() {
    sed -i 's/defaults,noatime/defaults,noatime,uquota,gquota,pquota/' /etc/fstab
    sed -i '0,/"$/s// rootflags=uquota,gquota,pquota"/' /etc/default/grub
    cp /boot/grub2/grub.cfg /boot/grub2/grub.cfg.orig
    grub2-mkconfig -o /boot/grub2/grub.cfg

    # manually reboot the headnode and then make default quotas like
    # xfs_quota -x -c 'limit -u bsoft=500m bhard=1000m -d' /
    # or run this script as root
    aws s3 cp --quiet "${post_install_base}/scripts/post.reboot.headnode.sh" "/root/" --region "${cfn_region}" || exit 1
    chmod +x "/root/post.reboot.headnode.sh"
}

installQuotaFSx() {
    echo "lfs setquota -u \${PAM_USER} -b 150000000 -B 200000000 /admin" >> /opt/parallelcluster/scripts/generate_ssh_key.sh
    echo "lfs setquota -u \${PAM_USER} -b 400000000 -B 500000000 /fsx" >> /opt/parallelcluster/scripts/generate_ssh_key.sh
}

changeNice() {
    # default niceness
    echo "@'Domain Users' soft priority 10" >> /etc/security/limits.conf
}


# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 01.install.disk.quota.headnode.sh: START" >&2
    #installQuota
    changeNice
    installQuotaFSx
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 01.install.disk.quota.headnode.sh: STOP" >&2
}

main "$@"