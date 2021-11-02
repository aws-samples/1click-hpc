# QuickStart
In case you do not want to use our 1Click-HPC Cloudformation template, but you still want to build your cluster with all the components and modules available in thie reporitory, you can follow the instruction below to configure your ParallelCluster configuration file. 
You can create a new cluster using your existing configuration file and just add the following parameters, everything will be installed and configured automatically.<br/>
If this is your first approach to AWS ParallelCluster, either go back to the section above or follow all the steps of our [Workshop](https://www.hpcworkshops.com/03-hpc-aws-parallelcluster-workshop.html) and include the following configuration:
```ini
[cluster yourcluster]
...
post_install = https://raw.githubusercontent.com/aws-samples/1click-hpc/main/scripts/post.install.sh
post_install_args = "05.install.ldap.server.headnode.sh 06.install.ldap.client.compute.sh 06.install.ldap.client.headnode.sh 10.install.enginframe.headnode.sh 11.install.ldap.enginframe.headnode.sh 20.install.dcv.slurm.headnode.sh 25.install.dcv-server.compute.sh 35.install.dcv.slurm.compute.sh"
extra_json = {"post_install":{"enginframe":{"ef_admin_pass":"Put_Your_Password_HERE"}}}
tags = {"EnginFrame" : "true"}
...
```
<blockquote id='PfT9CA19ub2'><b>Note:</b> You need to specify a custom Security Group (that allows inbound connection to the port 8443) defined as <b>`additional_sg`</b> parameter in the `[VPC]` section of your AWS ParallelCluster config file.</blockquote>

# (Optional) QuickStart parameters customization
In addition to the Quickstart deployment, there are a few parameters that you can optionally define to customize the components installed. <br/>
These parameters are defined as part of the <b> `extra_json` </b> [parameter](https://docs.aws.amazon.com/parallelcluster/latest/ug/cluster-definition.html#extra-json) in the [cluster section](https://docs.aws.amazon.com/parallelcluster/latest/ug/cluster-definition.html) of the AWS ParallelCluster configuration file.
If the <b> `extra_json` </b> is not specified, all the components will be installed using the default values. <br/> 
See below a example:
```json
{   
  "post_install": {
    "enginframe": {
      "nice_root": "/fsx/nice",
      "ef_admin": "ec2-user",
      "ef_conf_root": "/fsx/nice/enginframe/conf",
      "ef_data_root": "/fsx/nice/enginframe/data",
      "ef_spooler": "/fsx/nice/enginframe/spoolers",
      "ef_repository": "/fsx/nice/enginframe/repository",
      "ef_admin_pass": "Change_this!"
    },
    "dcvsm": {
      "agent_broker_port": 8445,
      "broker_ca": "/home/ec2-user/dcvsmbroker_ca.pem",
      "client_broker_port": 8446
    },
    "dcv": {
      "dcv_queue_keyword": "dcv"
    }
  }
}
```
 * <b>`nice_root`</b> by default `${SHARED_FS_DIR}/nice` , is the base directory where EnginFrame is installed. 
 * <b>`ef_admin`</b> by default `ec2-user` , is the EnginFrame user with administrative rights.
 * <b>`ef_conf_root`</b> by default `${NICE_ROOT}/enginframe/conf`, is the path of the EnginFrame configuration directory.
 * <b>`ef_data_root`</b> by default `${NICE_ROOT}/enginframe/data`, is the path of the EnginFrame data directory.
 * <b>`ef_spooler`</b> by default `${NICE_ROOT}/enginframe/spoolers`, is the path of the EnginFrame Spoolers. Please consider that the Spoolers are the loaction where your jobs are executed.
 * <b>`ef_repository`</b> by default `${NICE_ROOT}/enginframe/repository`, is the EnginFrame repository directory path.
 * <b>`ef_admin_pass`</b> by default `Change_this!` , is the EnginFrame admin password. Use this user and pass for your first login into EnginFrame.
 * <b>`agent_broker_port`</b> by default `8445`, is the DCV Session Manager Broker port.
 * <b>`broker_ca`</b> by default `/home/ec2-user/dcvsmbroker_ca.pem`, is the location for the DCV Session Manager Broker certificate.
 * <b>`client_broker_port`</b> by default `8446` , is the DCV Session Manager Broker port used by the client.
 * <b>`dcv_queue_keyword`</b> by default `dcv` , is a keyword that identifies the queues of your cluster where you want to enable DCV.

<i>**Note:** Because of the <b>`extra_json`</b> is a parameter in a <b>`.ini`</b> file, you need to put your custom json on a single line. 
You can use the following command to convert your json into a one-line json:</i>
```bash
tr -d '\n' < your_extra.json
```
<i>See below an example output.</i>
```json
{ "post_install": { "enginframe": { "nice_root": "/fsx/nice", "ef_admin": "ec2-user", "ef_conf_root": "/fsx/nice/enginframe/conf", "ef_data_root": "/fsx/nice/enginframe/data", "ef_spooler": "/fsx/nice/enginframe/spoolers", "ef_repository": "/fsx/nice/enginframe/repository", "ef_admin_pass": "Change_this!" }, "dcvsm": { "agent_broker_port": 8445, "broker_ca": "/home/ec2-user/dcvsmbroker_ca.pem", "client_broker_port": 8446 }, "dcv": { "dcv_queue_keyword": "dcv" }}}
```

# (Optional) Launch script customization
An additional way to further customize the installation and configuration of your components is by downlaoding the scripts locally, modify them, and put them back onto S3.<br/>
```bash
export S3_BUCKET=<YOUR_S3_BUCKET>

aws s3 cp --quiet --recursive 1click-hpc/scripts/         s3://$S3_BUCKET/scripts/
aws s3 cp --quiet --recursive 1click-hpc/packages/        s3://$S3_BUCKET/packages/
aws s3 cp --quiet --recursive 1click-hpc/parallelcluster/ s3://$S3_BUCKET/parallelcluster/
aws s3 cp --quiet --recursive 1click-hpc/enginframe/      s3://$S3_BUCKET/enginframe/
```

In this case, your AWS ParallelCluster configuration file has the following parameteres:
```ini
post_install = s3://<YOUR_S3_BUCKET>/scripts/post.install.sh
post_install_args = "01.install.enginframe.headnode.sh 03.install.dcv.slurm.headnode.sh 04.install.dcv-server.compute.sh 06.install.dcv.slurm.compute.sh"
```

The first one, <b>`post_install`</b>, specifies the S3 bucket you choose to store your post_install bash script. 
This is the main script that will run all the secondary scripts for installing EnginFrame, DCV Session Manager, DCV Server, and other components.<br/>
The second parameter, <b>`post_install_args`</b>, contains the scripts being launched for installing the selected components.<br/>
EnginFrame and DCV Session Manager Broker, and all the other secondary scripts are build indipendently, so you can potentially install just one of them.<br/>
<br/>

<blockquote id='PfT9CA19ub2'><b>Note:</b> This procedure has been tested with <i>EnginFrame version 2020.0</i> and <i>DCV Session Manager Broker version 2020.2. </i>With easy modifications, though, it can work with previous versions, just mind to add the license management.</blockquote>
<h2 id='PfT9CA9NvjI'>Requirements</h2>
To perform a successful installation of EnginFrame and DCV Sesssion Manager broker, you’ll need:<br/>
<div style="" data-section-style='5' class=""><ul id='PfT9CAZDjCH'><li id='PfT9CAEzM18' class='' value='1'><b>An S3 bucket,</b> made accessible to ParallelCluster via its <code>s3_read_resource</code> or <code>s3_read_write_resource</code> <code>[cluster]</code> settings. Refer to <a href="https://docs.aws.amazon.com/parallelcluster/latest/ug/configuration.html">ParallelCluster configuration</a> for details.
<br/></li><li id='PfT9CAHCVz5' class=''><b>An EnginFrame</b> <b><i>efinstall.config</i></b> file, containing the desired settings for EnginFrame installation. This enables post-install script to install EnginFrame in unattended mode. An example <i>efinstall.config</i> is provided in this post code: You an review and modify it according to your preferences.<br>Alternatively, you can generate your own one by performing an EnginFrame installation: in this case an <i>efinstall.config </i>containing all your choices will be generated in the folder where you ran the installation.
<br/></li><li id='PfT9CABUC6d' class=''><b>A</b> <b>security group allowing EnginFrame inbound port</b>. By default ParallelCluster creates a new security group with just port 22 publicly opened, so you can either use a replacement (via ParallelCluster <code>vpc_security_group_id</code> setting) or add an additional security group (<code>additional_sg</code> setting). In this post I’ll specify an additional security group.
<br/></li><li id='PfT9CAvkZ0P' class=''><b>ParallelCluster configuration including <code>post_install</code> and <code>post_install_args</code> </b>as mentioned above and described later with more details
<br/></li><li id='PfT9CASJBtH' class=''><b>(optionally) EnginFrame and DCV Session Manager packages</b>, available online from <a href="https://download.enginframe.com/">https://download.enginframe.com</a>. Having them in the bucket avoids the need for outgoing internet access for your ParallelCluster headnode to download them. In this article I’ll instead have them copied into my target S3 bucket. My scripts will copy them from S3 to the headnode node.
<br/></li></ul></div><blockquote id='PfT9CA2OdPe'><b>Note:</b> neither EnginFrame 2020 or DCV Session Manager Broker need a license if running on EC2 instances. For more details please refer to their documentation.</blockquote>

</li></ul></div><h1 id='PfT9CANUilh'>Troubleshooting</h1>
Detailed output log is available on the headnode node, in:<br/>
<div style="" data-section-style='5' class=""><ul id='PfT9CAgo7RL'><li id='PfT9CACrSe3' class='' value='1'>/var/log/cfn-init.log
<br/></li><li id='PfT9CACiH3u' class=''>/var/log/cfn-init-cmd.log
<br/></li></ul></div>You can reach it via ssh, after getting the headnode node IP address from AWS Console → EC2 → Instances and looking for an instance named <i>HeadNode</i>.<br/>

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.

