<h1> ParallelCluster post-install samples</h1>
This repository gather some <a href=https://docs.aws.amazon.com/parallelcluster/latest/ug/what-is-aws-parallelcluster.html><b>ParallelCluster</b></a> post-install samples for common HPC-related operations.
<br>Primary ParallelCluster script sets the environment and launches secondary scripts according to their naming convention.
<br>All those scripts are meant to be stored on an S3 bucket. See more details in the Requirements section below.

At the moment we are including:
1. *01.install.enginframe.master.sh*
    <br>Script installing <a href="https://www.nice-software.com"><b>NICE EnginFrame</b></a> HPC portal on the head node.
2. *02.install.dcv.broker.master.sh*
    <br>Script installing <a href="https://docs.aws.amazon.com/dcv/latest/sm-admin/what-is-sm.html"><b>DCV Session Manager Broker</b></a> on the head node.
3. *03.install.dcv.Slurm.master.sh*
    <br>Alternative to the previous, this script enables support for DCV sessions using Slurm instead of the DCV Session Manager Broker.
4. *04.install.dcv-server.compute.sh*
    <br>Script Configuring <a href="https://aws.amazon.com/hpc/dcv/"><b>DCV Server</b></a> on compute nodes.
5. *05.install.dcv-sm-agent.compute.sh*
    <br>Script installing and configuring <a href="https://docs.aws.amazon.com/dcv/latest/sm-admin/agent.html"><b>DCV Session Manager Agent</b></a>
6. *06.install.dcv.slurm.compute.sh*
    <br>Alternative to the previous, this script enables support for DCV sessions using Slurm instead of the DCV Session Manager Agent.

<h2 id='PfT9CA6xURy'>Software and Services used</h2>
<b>AWS ParallelCluster</b> is an open source cluster management tool that simplifies deploying and managing HPC clusters with Amazon FSx for Lustre, EFA, a variety of job schedulers, and the MPI library of your choice. AWS ParallelCluster simplifies cluster orchestration on AWS so that HPC environments become easy-to-use even for if you’re new to the cloud. <br/>
<br/>
<b>NICE EnginFrame</b> is the leading grid-enabled application portal for user-friendly submission,control and monitoring of HPC jobs and interactive remote sessions.It includes sophisticated data management for all stages of HPC job lifetime and is integrated with most popular job schedulers and middleware tools to submit, monitor, and manage jobs.<br/>
<br/>
<b>NICE DCV</b>  is a remote visualization technology that enables users to securely connect to graphic-intensive 3D applications hosted on a remote, high-performance server. With NICE DCV, you can make a server's high-performance graphics processing capabilities available to multiple remote users by creating secure client sessions. <br/>
<br/>
<b>NICE DCV Session Manager</b> is set of two software packages (an Agent and a Broker) and an application programming interface (API) that makes it easy for developers and independent software vendors (ISVs) to build front-end applications that programmatically create and manage the lifecycle of NICE DCV sessions across a fleet of NICE DCV servers. <br/>


# 1-Click Deployment
For Users who have no experience with AWS and no experience building an HPC Cluster, here an easy way to start.

#### Step 1
Click the link below corresponding to your preferred [AWS Region](https://aws.amazon.com/about-aws/global-infrastructure/regions_az/) .

| Region       | Launch                                                                                                                                                                                                                                                                                                             | 
|--------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| North Virginia (us-east-1)   | [![Launch](https://samdengler.github.io/cloudformation-launch-stack-button-svg/images/us-east-1.svg)](https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/quickcreate?templateUrl=https%3A%2F%2Fenginframe.s3.amazonaws.com%2FAWS-HPC-Cluster.yaml&stackName=aws-hpc-cluster) |

#### Step 2
Just change the "Stack Name" as you like, check the checkbox and click the "Create Stack".
</br>
![Step2](docs/step2.png?raw=true "Step 2")

#### Step 3
Click "Output" ....

# QuickStart
Create a new cluster using your configuration file and just add the following parameters, everything will be installed and configured automatically.<br/>
If this is your first approach to AWS ParallelCluster, either go back to the section above or follow all the steps of our [Workshop](https://www.hpcworkshops.com/03-hpc-aws-parallelcluster-workshop.html) and include the following configuration:
```ini
[cluster yourcluster]
...
post_install = https://raw.githubusercontent.com/aws-samples/aws-pcluster-post-samples/development/scripts/post.install.sh
post_install_args = "01.install.enginframe.master.sh 03.install.dcv.slurm.master.sh 04.install.dcv-server.compute.sh 06.install.dcv.slurm.compute.sh"
tags = {"EnginFrame" : "true"}
...
```
<blockquote id='PfT9CA19ub2'><b>Note:</b> You need to specify a custom Security Group (that allows inbound connection to the port 8443) defined as <b>`additional_sg`</b> parameter in the `[VPC]` section of your AWS ParallelCluster config file.</blockquote>

# (Optional) Custom QuickStart
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

# (Optional) Script customization
An additional way to further customize the installation and configuration of your components is by downlaoding the scripts locally, modify them, and put them back onto S3.<br/>
In this case, your AWS ParallelCluster configuration files have the following paramteres:
```ini
post_install = s3://<your_bucket>/scripts/post.install.sh
post_install_args = "01.install.enginframe.master.sh 03.install.dcv.slurm.master.sh 04.install.dcv-server.compute.sh 06.install.dcv.slurm.compute.sh"
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
<br/></li><li id='PfT9CABUC6d' class=''><b>A</b> <b>security group allowing EnginFrame inbound port</b>. By default ParallelCluster creates a new Master security group with just port 22 publicly opened, so you can either use a replacement (via ParallelCluster <code>vpc_security_group_id</code> setting) or add an additional security group (<code>additional_sg</code> setting). In this post I’ll specify an additional security group.
<br/></li><li id='PfT9CAvkZ0P' class=''><b>ParallelCluster configuration including <code>post_install</code> and <code>post_install_args</code> </b>as mentioned above and described later with more details
<br/></li><li id='PfT9CASJBtH' class=''><b>(optionally) EnginFrame and DCV Session Manager packages</b>, available online from <a href="https://download.enginframe.com/">https://download.enginframe.com</a>. Having them in the bucket avoids the need for outgoing internet access for your ParallelCluster master to download them. In this article I’ll instead have them copied into my target S3 bucket. My scripts will copy them from S3 to the master node.
<br/></li></ul></div><blockquote id='PfT9CA2OdPe'><b>Note:</b> neither EnginFrame 2020 or DCV Session Manager Broker need a license if running on EC2 instances. For more details please refer to their documentation.</blockquote>
<h2 id='PfT9CAAjFfa'>Step 1. Review and customize post-install scripts</h2>
GitHub code repository for this article contains 3 main scripts:<br/>
<div style="" class="" data-section-style='6'><ul id='PfT9CAcv9OY'><li id='PfT9CAqZmEr' class='' value='1'><i><b>post.install.sh </b></i><br>Primary post-install script, preparing the environment and launching secondary scripts in alphanumerical order
<br/></li><li id='PfT9CAcXiVn' class=''><b><i>01.install.enginframe.master.sh</i></b><br>Secondary script installing EnginFrame<br>Most installation parameters are up to <b><i>efinstall.config</i></b> script
<br/></li><li id='PfT9CAvmQMT' class=''><b><i>02.install.dcv.broker.master.sh</i></b><br>Secondary script installing DCV Session Manager Broker
<br/></li></ul></div>Secondary scripts follow this naming convention: they <b>start with a number that will set their execution order</b>, then they <b>describe their purpose</b>, and finally <b>define the node type in which they should be executed</b> (master or compute) as a last argument, just before the extension, e.g.:<br/>
<pre id='PfT9CA3RKNQ'><b><span bgcolor="#d7f7d4" style="background-color:#d7f7d4">01</span>.<span bgcolor="#ffcdcc" style="background-color:#ffcdcc">install</span><span bgcolor="#ffcdcc" style="background-color:#ffcdcc">.enginframe</span>.<span bgcolor="#ffe600" style="background-color:#ffe600">master</span>.<span bgcolor="#9ee9fa" style="background-color:#9ee9fa">sh</span></b><br><span bgcolor="#d7f7d4" style="background-color:#d7f7d4">|</span>  <span bgcolor="#ffcdcc" style="background-color:#ffcdcc">|</span>                  <span bgcolor="#ffe600" style="background-color:#ffe600">|</span>      <span bgcolor="#9ee9fa" style="background-color:#9ee9fa">|</span>     <br><span bgcolor="#d7f7d4" style="background-color:#d7f7d4">|</span>  <span bgcolor="#ffcdcc" style="background-color:#ffcdcc">|</span>                  <span bgcolor="#ffe600" style="background-color:#ffe600">|</span>      <span bgcolor="#9ee9fa" style="background-color:#9ee9fa">file extension</span><br><span bgcolor="#d7f7d4" style="background-color:#d7f7d4">|</span>  <span bgcolor="#ffcdcc" style="background-color:#ffcdcc">purpose</span>            <code><span bgcolor="#ffe600" style="background-color:#ffe600">|</span></code><br><span bgcolor="#d7f7d4" style="background-color:#d7f7d4">|</span>                     <span bgcolor="#ffe600" style="background-color:#ffe600">to be run on master </span><span bgcolor="#ffe600" style="background-color:#ffe600">or compute nodes</span><br><span bgcolor="#d7f7d4" style="background-color:#d7f7d4">execution order</span></pre>
While main post-install script <i>post.install.sh</i> just sets environment variables and launches secondary scripts, you might want to check the secondary ones: <i>01.install.enginframe.master.sh</i> installing EnginFrame and <i>02.install.dcv.broker.master.sh </i>installing DCV Session Manager Broker.<br/>
<br/>
Crucial parameters are set in ParallelCluster configuration file, and some EnginFrame settings are defined into <i>efinstall.config</i> file. All these files should be checked to reflect what you have in mind.<br/>
<br/>
You can also add further custom scripts, in the same folder, following the naming convention stated above. An example could be installing an HPC application locally on a compute node, or in the master shared folder.<br/>
<br/>
Each script sources <b><i>/etc/parallelcluster/cfnconfig</i></b> to get the required information about current cluster settings, AWS resources involved and node type. Specifically, cfnconfig defines <br/>
<div style="" data-section-style='5' class=""><ul id='PfT9CAvyMeE'><li id='PfT9CADVG1H' class='' value='1'><code>cfn_node_type=<b>MasterServer</b></code> if current node is the master node 
<br/></li><li id='PfT9CA7EIAI' class=''><code>cfn_node_type=<b>ComputeFleet</b></code> if current node is a compute node
<br/></li></ul></div><blockquote id='PfT9CAB7egs'><b>Note:</b> More details on each scripts are provided in <b>Post-install scripts details</b> section following the <b>Walktrough</b>.</blockquote>
<h2 id='PfT9CA9XRzC'>Step 2. <b>Prepare your S3 bucket</b> </h2>
I create an S3 Bucket e.g. <code>mys3bucket</code>, with the following structure and contents in a prefix of choice (Packages names and version numbers may vary):<br/>
<pre id='PfT9CAWCFW4'>packages<br>├── NICE-GPG-KEY.conf<br>├── efinstall.config<br>├── enginframe-2020.0-r58.jar<br>└── nice-dcv-session-manager-broker-2020.2.78-1.el7.noarch.rpm<br>scripts<br>├── 01.install.enginframe.master.sh<br>├── 02.install.dcv.broker.master.sh<br>└── post.install.sh</pre>
<h2 id='PfT9CAo7SeV'><b>Step 3. Modify or create your ParallelCluster configuration file</b></h2>
As mentioned, the only settings required by my scripts are the following in the <code><b>[cluster]</b></code> section:  <code>post_install</code>, <code>post_install_args</code> and <code>s3_read_resource</code>:<br/>
<pre id='PfT9CAWhRVy'>post_install = s3://&lt;bucket&gt;/&lt;bucket key&gt;/scripts/post.install.sh<br>post_install_args = '&lt;bucket&gt; &lt;bucket key&gt; &lt;efadmin password (optional)&gt;'<br>s3_read_resource = arn:aws:s3:::&lt;bucket&gt;/&lt;bucket key&gt;/*</pre>
The <i>post.install.sh</i> main script is set as the <code>post_install</code> option value, with its S3 full path, and provided arguments:<br/>
a) bucket name <br/>
b) bucket folder/key location<br/>
c) efadmin user (primary EnginFrame administrator) password<br/>
all separated by space. All post install arguments must be enclosed in a <b>single pair</b> of single quotes, as in the example code.<br/>
Finally, the <code>s3_read_resource</code> option grants the master access to the same S3 location to download secondary scripts: first one installing EnginFrame <i>(01.install.enginframe.master.sh) </i>and second one installing DCV Session Manager broker <i>(02.install.dcv.broker.master.sh).</i><br/>
<br/>
<blockquote id='PfT9CAHIvuh'><b>Note:</b> you may wish to associate a custom role to the ParallelCluster master instead of using the <code>s3_read_resource</code> option.</blockquote>
<br/>
<blockquote id='PfT9CARo4zK'><b>Note: </b>ParallelCluster documentation suggests to use double quotes for <code>post_install_args</code>. This is not working with the last version of parallelcluster available when writing this article, so I’m using single quotes. This is under fixing and will probably change in near future.</blockquote>
<br/>
A configuration file sample is provided under the <i>parallelcuster</i> folder of the github repository.<br/>
<h2 id='PfT9CASKaeI'>Step 4. Create ParallelCluster</h2>
You can now start ParallelCluster creation with your preferred invocation command, e.g.:<br/>
<pre id='PfT9CA7tiTl'>pcluster create --norollback --config parallelcluster/config.sample PC291</pre>
<blockquote id='PfT9CAnwMy7'><b>Hint: </b>when testing it’s probably better to disable rollback like in the above command line: this will allow you to connect via ssh to the Master instance to diagnose problems if something with the post-install scripts went wrong.</blockquote>
<h2 id='PfT9CAEO4Mv'>Cleaning up</h2>
To avoid incurring future charges, delete idle ParallelCluster instances via its delete command:<br/>
<pre id='PfT9CAqIN4q'><code>pcluster </code><code>delete</code><code> --config parallelcluster/config.sample PC291</code></pre>
<h1 id='PfT9CAhGMZ6'>Post-install scripts details</h1>
In this section I’ll list some more details on the scripts logic. This could be a starting point in customizing, evolving or adding more secondary scripts to the solution. For example, you might want to add a further script to automatically install an HPC application into ParallelCluster master node.<br/>
<h2 id='PfT9CAO6eGz'>Main post.install.sh</h2>
Post-install script <b><i>post.install.sh</i></b> goes through the following steps:<br/>
<div style="" class="" data-section-style='6'><ul id='PfT9CAKRjQV'><li id='PfT9CA9y111' class='' value='1'>Gets post-install arguments, and exports them as environment variables, in particular:<br><code>export S3Bucket="$2"<br>export S3Key="$3"<br>export efadminPassword="$4"</code>
<br/></li><li id='PfT9CAOmgnZ' class=''>Downloads the entire scripts subfolder from the S3 bucket into master node <i>/tmp/scripts</i> folder
<br/></li><li id='PfT9CAJLPMI' class=''>Runs every script in <i>/tmp/scripts</i> in alphanumerical order
<br/></li></ul></div><h2 id='PfT9CAnh9Qk'>EnginFrame</h2>
Provided script <b><i>01.install.enginframe.sh</i></b> performs the following steps:<br/>
<div style="" class="" data-section-style='6'><ul id='PfT9CAn3gVJ'><li id='PfT9CAuw7jM' class='' value='1'>Installs <i>openjdk</i> (required for EnginFrame)
<br/></li><li id='PfT9CA0ZuUe' class=''>Downloads the packages subfolder of the bucket into <i>/tmp/packages.</i> So it gets EnginFrame installer and also any other secondary script in advance
<br/></li><li id='PfT9CAV3XE1' class=''>Checks if EnginFrame installer and <i>efinstall.config</i> are available under <i>/tmp/packages</i>
<br/></li><li id='PfT9CAFyXyA' class=''>Inline modifies its <i>efinstall.config</i> copy to install EnginFrame under ParallelCluster shared folder <code>cfn_shared_dir</code>
<br/></li><li id='PfT9CAcxPCI' class=''>Adds efadmin and efnobody local users, again required by EnginFrame. Sets efadmin password if present. If not present you should set it later, for example by connecting via ssh to the master node
<br/></li><li id='PfT9CADPT3i' class=''>Installs EnginFrame in unattended mode into the ParallelCluster shared folder
<br/></li><li id='PfT9CAC6Z9W' class=''>Enables and starts EnginFrame service
<br/></li></ul></div><h2 id='PfT9CALuVCp'>DCV Session Manager Broker</h2>
Provided script <b><i>02.install.dcv.broker.master.sh</i></b> performs the following steps:<br/>
<div style="" class="" data-section-style='6'><ul id='PfT9CAeeBLr'><li id='PfT9CA3PqcJ' class='' value='1'>Downloads the packages sobfolder of the bucket into <i>/tmp/packages</i>
<br/></li><li id='PfT9CAT5zwj' class=''>Checks if NICE-GPG-KEY and DCV Session Manager Broker package are available under <i>/tmp/packages</i>
<br/></li><li id='PfT9CASxotS' class=''>Imports NICE-GPG-KEY and installs DCV Session Manager Broker rpm
<br/></li><li id='PfT9CAeq7Sk' class=''>Modifies broker configuration to switch port to 8446 since 8443 is used by EnginFrame 
<br/></li><li id='PfT9CACCXQw' class=''>Enables and starts DCV Session Manager Broker service
<br/></li><li id='PfT9CA3Tnxp' class=''>Copies DCV Session Manager Broker certificate under efadmin’s home
<br/></li></ul></div>Optionally, if EnginFrame is installed, it:<br/>
<div style="" class="" data-section-style='6'><ul id='PfT9CA7h8V4'><li id='PfT9CAEkoP5' class='' value='1'>Registers EnginFrame as API client
<br/></li><li id='PfT9CAQz5b5' class=''>Saves API client credentials into EnginFrame configuration
<br/></li><li id='PfT9CAQeIg1' class=''>Adds DCV Session Manager Broker certificate into Java keystore
<br/></li><li id='PfT9CAijDzb' class=''>Restarts EnginFrame
<br/></li></ul></div><h1 id='PfT9CANUilh'>Troubleshooting</h1>
Detailed output log is available on the master node, in:<br/>
<div style="" data-section-style='5' class=""><ul id='PfT9CAgo7RL'><li id='PfT9CACrSe3' class='' value='1'>/var/log/cfn-init.log
<br/></li><li id='PfT9CACiH3u' class=''>/var/log/cfn-init-cmd.log
<br/></li></ul></div>You can reach it via ssh, after getting the master node IP address from AWS Console → EC2 → Instances and looking for an instance named <i>Master</i>.<br/>

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.

