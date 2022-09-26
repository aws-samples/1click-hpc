#!/bin/bash
set -x
set -e
source '/etc/parallelcluster/cfnconfig'

installCustom() {
    amazon-linux-extras install epel -y
    yum install -y knot-resolver knot-utils knot-resolver-module-http
    mac=$(curl http://169.254.169.254/latest/meta-data/mac)
    cidrblock=$(curl http://169.254.169.254/latest/meta-data/network/interfaces/macs/${mac}/vpc-ipv4-cidr-block)
    read A B C D <<<"${cidrblock//./ }"
    read E F <<< "${D//// }"
    G=$((${E}+2))
    vpcdns="${A}.${B}.${C}.${G}"
    
    echo "supersede domain-name-servers 127.0.0.1, ${vpcdns};" >> /etc/dhcp/dhclient.conf

    echo "net.listen(net.lo, 8053, { kind = 'webmgmt' })" >> /etc/knot-resolver/kresd.conf
    echo "internalDomains = policy.todnames({'ec2.internal', '${stack_name}.pcluster','${cfn_region}.amazonaws.com'})" >> /etc/knot-resolver/kresd.conf
    echo "policy.add(policy.suffix(policy.FLAGS({'NO_CACHE'}), internalDomains))" >> /etc/knot-resolver/kresd.conf
    echo "policy.add(policy.suffix(policy.STUB({'${vpcdns}'}), internalDomains))" >> /etc/knot-resolver/kresd.conf

    systemctl enable --now kresd@{1..2}.service
    dhclient
}


# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 00.install.knot.resolver.cpu.sh: START" >&2
    installCustom
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 00.install.knot.resolver.cpu.sh: STOP" >&2
}

main "$@"