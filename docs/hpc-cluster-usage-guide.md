## CLUSTER RULES

1. do not run any workload on the login node

   1. you can create your venv, use pip install
   2. never use the /home dir to store the venv, or any data
   3. symlink your ~/.cache to some folder on fsx cause some packages will try to write temp data into the above and break item b
   4. if you need to transfer data, do so from a compute node such as this `srun --partition=login --nodes=1 --ntasks-per-node=1 --cpus-per-task=2 --pty bash -i`

2. the only IDE allowed to connect is VS Studio

   1. do NOT use/install the TabNine module on the remote computer

3. do not attempt to write millions of small files to network volumes, this includes the fsx and S3 storage. Instead, pack them into webdataset format and save larger and fewer files. Please learn webdataset format, it is very important in the HPC context

   1. some people kept cc12m and similar datasets on fsx; I moved them to s3. This is bad enough, and time should be invested in converting all these old datasets to the proper webdataset format. Working with the native format brings very high expenses to the cluster, much higher than the effort to convert them just once

4. if we find processes on the headnode that will create a high load on the network, we will kill them and

   1. ban you for three days at first transgression
   2. ban you for two weeks at the second
   3. ban you permanently at the third

Note: AWS is working on improved cluster architecture. This will feature separate login nodes (i.e. cluster manager will not be located on the login nodes). This will perhaps render these rules not necessary anymore. Until it happens, we must live with what we have, and everyone's jobs should be secure in the cluster.

## Introduction & Overview

Welcome to Stability.AI! Documentation is a work in progress, so please bare with us.

This means that documentation, example configs, and scripts are prone to change from time to time.

In addition to this document, which contains more detailed information, please see the following resources.

- **[Stability Quickstart Guide](https://docs.google.com/document/d/1AAI_BSbfXv1rIhrZVRbpM1iIQQS8sMjwufK0WjcHZRc/edit#)**

  - Quickly get up and running with distributed jobs on the HPC cluster.

- **[S3 storage and Dataset Guide](https://docs.google.com/document/d/1ajnYyCe-dN6k2UVF8XYxCobTI5185pzfA2pQFqKe6pU/edit)**

  - For information and tips on using S3 storage to manage large datasets.

- **[Slurm Quick Start User Guide](https://slurm.schedmd.com/quickstart.html).**

  - Overview of the scheduler which manages the HPC cluster.

Users all connect to the cluster via what’s known as the “headnode”, from which you later request compute resources via [SLURM](https://slurm.schedmd.com/documentation.html). 

- The 3600 A100 Production Headnode is  **login.hpc.stability.ai**
- The 200 A100 Sandbox Headnode is **sandbox.hpc.stability.ai**

Note: the sandbox cluster can be accessed with password- or key-based SSH, while the production cluster can only be accessed with key-based SSH.

## Cluster updates

Updates are rolled out as new cluster head nodes working against the same compute fleet capacity. They compete for the compute resources, allowing a smooth transition to a new cluster when the jobs from the old cluster finish.

The transition requires that all data resides on /fsx rather than the home folder.

HPC v4 - August 14

- cluster upgraded to v3.2.0

- cluster can mount multiple fsx volumes on all nodes

- renamed partitions for simplicity

- GPU partition is the default partition

- added memory based scheduling

- added DCGM for GPU profiling

- added EFA and Accelerator metrics to CloudWatch

- added Project-based accounting

  - users must introduce project name
  - users must be part of the project
  - with budgeting activated, jobs will run only if budget exists (feature will be rolled-out with some delay)

- added cluster portal (admins only, to be rolled out to users later)

- upgraded HPC users self-service portal

  - password expiration and account expiration email reminders
  - profile with mandatory identification details
  - upload ECDSA public SSH key for passwordless login
  - password logins will be retired after all users update profiles to the above requirements
  - frontend cleaned up by removing unnecessary items

- fixed containers infrastructure

- all GPU nodes feature a local fast nvme based disk 7.2TB mounted at /scratch

- removed enginframe

**Important instructions:** quota management only allows you to run jobs for the projects you are allocated. Nevertheless, you are allocated by default to your affiliated institution: Stability, Laion, Eleuther, MILA, CompVis etc. All jobs launched with the project set as the affiliate institution **WILL BE preemptible**. This means the compute nodes can be requested by high-priority jobs immediately, crashing your script. **Please make scripts resilient to preemption** for such jobs. This setup is intended for everyone to be able to run preemptible jobs when the GPUs are idle. Detailed instructions about how to set such jobs will follow next week. As opposed to the above, jobs launched for projects with quotas will have high priority and preempt the above at the start.

You have to specify the target project for the job to be launched with: `--comment ProjectName`. For the above affiliation please use their names in lowercase.

Use this for both sbatch and srun commands. Use it for `srun` commands inside the `sbatch` file too like:

```
#!/bin/bash
#SBATCH --partition=gpu
#SBATCH --job-name=idle-translation
#SBATCH -t 7-00:00  # time limit: (D-HH:MM)
#SBATCH --output=LOGS/%x\_%j.out
#SBATCH --cpus-per-task=48
#SBATCH --nodes=107
#SBATCH --ntasks-per-node=1
#SBATCH --exclusive
#SBATCH --requeue
#SBATCH --comment laion

module load openmpi

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/nccl/build/lib:/opt/aws-ofi-nccl/lib
export NCCL_PROTO=simple
export PATH=$PATH:/opt/amazon/efa/bin:/opt/amazon/openmpi/bin
export FI_EFA_FORK_SAFE=1
export FI_LOG_LEVEL=1
export FI_EFA_USE_DEVICE_RDMA=1 # use for p4dn
export NCCL_DEBUG=info
export OMPI_MCA_mtl_base_verbose=1
export FI_EFA_ENABLE_SHM_TRANSFER=0
export FI_PROVIDER=efa
export FI_EFA_TX_MIN_CREDITS=64
export NCCL_TREE_THRESHOLD=0
export OMPI_MCA_pml="^openib"

source my-project-env/bin/activate && srun **--comment Laion** python3 translate_data.py
```

if you are unsure which projects you are allowed to use, find it like this:

`[login_node ~]$ id --groups --name

laion Domain Users AWS Delegated Add Workstations To Domain Users`

Ignore these groups:

- Domain Users
- AWS Delegated Add Workstations To Domain Users

It means the user has only access to the project `laion`. The name is case sensitive.

HPC v3 - July 24, 2022 changelog:

- 320 instances are now static, i.e. they are up at all times. This will help with blocking defective ones while AWS is debugging the hardware
- launching jobs should be instant now, including large ones
- for the moment tagging to send metrics to grafana is not working; it will be addressed
- HPC splash page at[ https://hpc.stability.ai/](https://hpc.stability.ai/) is redesigned grace to our nice designers
- you can attempt scaling jobs at any size provided there are enough nodes available in sinfo
- please add error wrapper code (see appendix 2) to your scripts so we can catch defective GPUs

HPC v2 - July 10, 2022 changelog:

- faster head node networking (4x)
- added head node home folder disk quota (30GB soft limit, 40GB hard limit)
- ssh key management can be performed directly in Active Directory (we can get rid of passwords ultimately) - still requires deleting the cache for existing users
- made a particular **jupyter** partition to launch jupyter notebooks
- installed knot resolver on **cpu** nodes (needed for fast dns queries in case of using _img-2-dataset_) 
- multiple clusters can now coexist with same fsx volume, AD and compute nodes for seamless upgrades (still needs testing during the next cluster upgrade)
- slurm accounting improvements

HPC v1 July 1st, 2022 Initial headnode was retired. 


## 
## Stability HPC Cluster Overview

Stability HPC is built around the AWS ParallelCluster solution. Here is an overview of the cluster architecture:

![](https://lh5.googleusercontent.com/QfC4Vg8cW8KzKS8L-u7js3Xhjblu3R0RiXsVzLGsANHVYumRLRuUTd41YEpA_d47oCynPFZhuiwGbYvm8KI04gMgQAPZEk05TD4aNRnuh6Mcq12nSERT3k5GR2wN96kHZcE3p6_0FFEyDm8Bq-xPu_llbhuVTNChbHt7oRnTL1DrGEVwKogzWtixEQ)

Stability HPC cluster has slightly different queues; information can be retrieved from any node by running the sinfo command.

ParallelCluster has an instance named HeadNode. Users are connecting to the cluster by accessing this node via `ssh yourusername@headnode`.

If you set your public SSH key, you should be able to use `ssh -i path/privatekey username@headnode` instead. 

We also expose a web interface to the cluster where you can access your workspace (and browse the file systems, including FSx) at <https://hpc.stability.ai>  with the same credentials as above.

Now, the compute fleet is configured with a minimum of 320 and a maximum of 330 compute nodes of type p4d. there are also CPU nodes available if you have to run CPU-only jobs. Not all these instances are available, so it is best to coordinate with the DevOps team to understand how many instances you can request. 

The entire compute fleet is managed by a scheduler manager named [SLURM](https://slurm.schedmd.com/documentation.html). This document only provides a very rough overview of the Slurm workflow, so please also read the [Slurm Quick Start User Guide](https://slurm.schedmd.com/quickstart.html).


### Compute allocation

They will happen based on projects and quotas for each project. Users can launch jobs against the project quota, and some accounting algorithms will track the usage. 

Please note that in Slurm, if you ask for too many instances and they are unavailable, your job will probably never be executed. 

We will slowly introduce ways to minimise compute waste, such as utilising 1-2 GPUs for dev purposes or even fractions of GPUs via MIG functionality. We will also deploy colab-style notebook servers to optimise the development process further.


### Nodes and storage

Compute nodes are ephemeral, meaning they are only launched if a job appears in the slurm queue; also, they are terminated once all jobs are finished, and the queue is empty. Therefore the filesystem inside the compute nodes is temporary, too, with two exceptions: these nodes will mount your home folder and the /fsx folder, which are both persistent. FSx is more persistent than the storage of the HeadNode, though (remember data backup, etc.) and also is very fast, making it ideal for checkpoint saving and so on. 

Please remember to keep the FSx storage clean, i.e. move out final results once the job is done, preferably by tar-ing and transferring to S3. See [**S3 storage and Dataset Guide**](https://docs.google.com/document/d/1ajnYyCe-dN6k2UVF8XYxCobTI5185pzfA2pQFqKe6pU/edit) for more information.


## Configure your Stability.AI login

**If you were given a temporary password, please change your temporary password ASAP.**

**During the first login on the self-service portal at **<https://hpc.stability.ai:8888>** you will be asked to fill out your profile.**

It is recommended to add your **ed25519 _public SSH key_** as well because, in the future, access to the cluster will be restricted to key-based SSH logins. **_Standard RSA keys will not fit the size of that field and will not function. ECDSA keys will fit, but they are less secure._**

`ssh-keygen -t ed25519`

After the key pair is generated, you will be presented with two new files like **somekeyname** and **somekeyname.pub**. These files are part of a cryptography system meant to maintain a secure connection and a secure authorisation to access a remote resource. The specific of public key cryptography is that the public part can be shared with the rest of the world while the private part must be kept secret. This is why the key pair is best created from the home computer so that the private key never gets transferred over the wire. Once generated, please place the safe shareable key, somekeyname.pub, into the profile in the portal

COPY output of **cat ~/.ssh/somekeyname.pub** that should look like

`ssh-ed25519 AAAA……`

into

![](https://lh3.googleusercontent.com/HYWXsFSDl1A6zRUQzTJcMZrBZfJVHNPg2-93B7_NkuOGRo10xLKMDO_g-AxsR6My1i7Zt6WDAWVWBOumr50NFB7rnEEi4UqlTJIYcZ0e9diUfgk75pCIE6W8aU-lvc_SDp-qMS90DWxurCfwfukfW_j7lovmDY5o_d1EoStYLHQP65UTeLW7V2ivIg)

**Your password will still be needed for future profile edits. You can install the mobile app and enrol if you want your account protected with MFA.**

- Please check [Appendix 1](https://docs.google.com/document/d/1eMJaVj1B_fhA-qU57ATZInqmA36nyDTuEL9G5ip1YIQ/edit#heading=h.k4iq1lzhr2ta) for password complexity requirements.


- **ADSelfService Plus** mobile app: push notification or fingerprint/faceID features:

  - Google authenticator
  - Microsoft authenticator
  - basic security questions if you have none of the above


## Workflow Overview

In general, the procedure for utilising the HPC cluster is as follows:

1. Connect to the cluster’s head node via SSH

2. Prepare your environment, code and container at the persistent FSX storage.

3. Request resources and launch a job using SLURM

   1. Name your job with the current project name you are working on.


### Inspect the cluster.

There are multiple ways to inspect the cluster and the jobs that are scheduled upon it.

Following is a short overview of some methods available to you, with more details in the [Inspecting and Monitoring the cluster](https://docs.google.com/document/d/1eMJaVj1B_fhA-qU57ATZInqmA36nyDTuEL9G5ip1YIQ/edit#heading=h.7pyrs8xvaw0u) section:

- **[sinfo](https://slurm.schedmd.com/sinfo.html)**

  - **Yields an overview of the Slurm system, displaying the different partitions and the theoretically available quantity for each partition.**

- **[squeue](https://slurm.schedmd.com/squeue.html)**

  - List the jobs currently active in the Slurm system. This includes both jobs that are currently running and jobs that are scheduled but yet to be allocated resources.

- The [Hpc.Stability.AI](https://hpc.stability.ai/) user workspace

  - A dashboard containing information about jobs requested from your account.

- [Grafana Monitoring](https://grafana.com/)

  - An admin-based dashboard providing general information about the cluster and its workload.
  - Accessible under the “Cluster Monitoring Dashboard” section at [Hpc.Stability.AI](https://hpc.stability.ai/) 


### Launching jobs

The head node you connect to via SSH is not designed to perform any meaningful computation. Instead, you run jobs on the cluster by submitting a Slurm job request, specifying what commands to execute and the required resources. Slurm continuously schedules incoming job requests and takes care of distributing and executing the job instructions when its computing resources are allocated.

A job request to Stability.AI should specify its required resources and be **named per the current project you’re working on**. Additionally, you can specify various settings such as max duration and the output destination. These settings can be added via the shell command or, more conveniently, via a batch script. See details and examples in [Allocating and running jobs](https://docs.google.com/document/d/1eMJaVj1B_fhA-qU57ATZInqmA36nyDTuEL9G5ip1YIQ/edit#heading=h.6dcvzqghlrop).

For most use cases, you can manage your jobs with the following Slurm commands:

- [**srun**](https://slurm.schedmd.com/srun.html) 

  - Starts and runs a parallel job
  - Can be executed on its own, which is useful when creating an interactive shell session.
  - When called from within a batch script,** **it executes the given command on (unless specified otherwise) all allocated job tasks.

- [**sbatch**](https://slurm.schedmd.com/sbatch.html):

  - Runs a batch script that writes the output of the (potentially many) threads into an output file.

- [**scancel**](https://slurm.schedmd.com/scancel.html):

  - Cancels an ongoing or scheduled job by providing the specific job ID.


#### Launching an interactive session

For debugging and getting up and running, one can start an interactive job.

For example, the following command requests a job with an interactive bash session.
```
srun --partition=gpu --nodes=1 --gpus=8 --cpus-per-gpu=6 --job-name=MyProject --pty bash -i
```
The arguments should be interpreted as follows:

- **partition**

  - Specify our work to run on the “_gpu partition_”
  - See the [Slurm Quickstart](https://slurm.schedmd.com/quickstart.html) for more info on partitions

- **nodes=1  **& ** gpus-per-node=8 ** & ** cpus-per-gpu=6**

  - Allocate one node with 8 GPUs and 8\*6=48 CPUs

- **job-name**

  - Names our job _“MyProject”_

- **pty**

  - Set the job to execute in interactive mode

- **i**

  - The [**immediate**](https://slurm.schedmd.com/srun.html#OPT_immediate) argument specifies to only run the command if resources are available immediately.


#### Jupyter Notebooks

You can launch a Jupyter Notebook server within the HPC cluster with 1GPU and 48 hours time limit using this command:
```
sh /fsx/shared/jupyter.sh
```
Please close the job at the end if used less than 48 hours. to do so, follow these steps:

1. ssh into headnode as usual
2. run squeue; this will list all your active jobs with names
3. spot the jupyter jobs, note the job IDs
4. run scancel ID for every jupyter job you need to cancel
5. confirm with squeue that all jobs were terminated.

Once the accounting will be implemented, the total duration of the run will be deducted from your quota. It is important to save quota. Thank you.


### Environments & Containers

Please prepare your environments in the HeadNode under the persistent storage at /fsx

We have installed python3.8 everywhere, including venv and devel modules. To build it, please use python3.8 instead of just python and python3.

Please note that non-interactive slurm jobs will not execute .bashrc or profile.d scripts. You need to prepare the compute node environment variables from the headnode. Read further down for examples.

The compute nodes come with two ways to run containerised projects

1. **Singularity**

   1. A drop-in replacement that runs docker images in the user context without much fuss.

2. **Nvidia ****_enroot/pyxis_**** **

   1. A containerisation solution combined with a slurm plugin from Nvidia. Unlike Singularity which is not supported by AWS, the enroot path is supported therefore preferred when you ponder what to choose

For mor information and examples see [Section: Running containers](https://docs.google.com/document/d/1eMJaVj1B_fhA-qU57ATZInqmA36nyDTuEL9G5ip1YIQ/edit#heading=h.5si17gs995wt)


## Detailed Documentation


### Inspecting and Monitoring the cluster


#### The sinfo command

Running:
```
sinfo
```
Yields:
```
PARTITION        AVAIL  TIMELIMIT  NODES  STATE NODELIST

cpu\*     up   infinite   1100  idle~ cpu-dy-c6i-32xlarge-\[1-300],cpu-dy-m5zn-12xlarge-\[1-100],cpu-dy-m6i-32xlarge-\[1-300],cpu-dy-r6i-32xlarge-\[1-300],cpu-dy-x2iezn-12xlarge-\[1-100]

gpu      up   infinite     64  idle~ gpu-dy-p4d-24xlarge-\[1-64]

jupyter     up   infinite    194  idle~ mig-dy-p4d-24xlarge-\[1-194]

spot-cpu    up   infinite   1000  idle~ compute-spot-cpu-dy-c6i-32xlarge-\[1-300],compute-spot-cpu-dy-m5zn-12xlarge-\[1-100],compute-spot-cpu-dy-m6i-32xlarge-\[1-300],compute-spot-cpu-dy-r6i-32xlarge-\[1-300]
```
You will see that slurm has a number of queues (or partitions in slurm lingua). Partitions will display instance types and the quantity theoretically available for each partition.


#### Grafana Monitoring

We can monitor the cluster with Grafana monitoring available at the “Cluster Monitoring Dashboards” section at <https://hpc.stability.ai> . To log in, please use credentials provided by the HPC staff.

Activating monitoring for your job is WIP. I will update here with new instructions when done.


### Allocating and running jobs

This is an example of how to run the nccl tests, and it is a good template to run another kind of distributed jobs based on nccl:
```
#!/bin/bash\
#SBATCH --partition=gpu
#SBATCH --job-name=nccl-tests
#SBATCH --nodes=40
#SBATCH --ntasks-per-node=8
#SBATCH --exclusive
#SBATCH --output=%x\_%j.out

module load openmpi
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/nccl/build/lib:/opt/aws-ofi-nccl-install/lib
export NCCL_PROTO=simpleexport LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/aws-ofi-nccl/lib
export PATH=$PATH:/opt/amazon/efa/bin:/opt/amazon/openmpi/bin
export FI_EFA_FORK_SAFE=1
export FI_LOG_LEVEL=1
export FI_EFA_USE_DEVICE_RDMA=1 # use for p4dn
export NCCL_DEBUG=info
export OMPI_MCA_mtl_base_verbose=1
export FI_EFA_ENABLE_SHM_TRANSFER=0
export FI_PROVIDER=efa
export FI_EFA_TX_MIN_CREDITS=64
export NCCL_TREE_THRESHOLD=0
export OMPI_MCA_pml="^openib"

srun /opt/nccl-tests/build/all_reduce_perf -b 128M -e 8G -f 2 -g 1 -c 1 -n 20
```
The above set environment is the right one to activate EFA internode comms.


### 
### Running containers,

The compute nodes come with two ways to run containerised projects

1\. Singularity is an HPC-friendly drop-in replacement for docker that runs docker images in the user context without much fuss. It integrates as simple as any other command. to run something; you can do

`singularity exec --nv --bind /fsx:/fsx docker://image:tag nvidia-smi`

to execute nvidia-smi interactively.

`singularity shell --nv --bind /fsx:/fsx docker://image:tag`

to get a shell into the container.

Note the way to bind the host os folder into the container. Also --nv is required to expose Nvidia resources to the container

Here is how to run nccl tests in a container. It features the docker image baseami that should be the starting point for your own container image:

```
#!/bin/bash
#SBATCH --partition=gpu
#SBATCH --job-name=nccl-tests
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=8
#SBATCH --exclusive
#SBATCH --mem=64GB
#SBATCH --output=%x\_%j.out

module load openmpi
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/nccl/build/lib:/opt/aws-ofi-nccl/lib
export PATH=$PATH:/opt/amazon/efa/bin:/opt/amazon/openmpi/bin
export FI_EFA_FORK_SAFE=1
export FI_LOG_LEVEL=1
export FI_EFA_USE_DEVICE_RDMA=1 # use for p4dn
export FI_EFA_ENABLE_SHM_TRANSFER=0
export FI_PROVIDER=efa
export FI_EFA_TX_MIN_CREDITS=64
export NCCL_DEBUG=warn
export NCCL_PROTO=simple
export NCCL_TREE_THRESHOLD=0
export OMPI_MCA_mtl_base_verbose=1
export OMPI_MCA_btl="^openib"
export SINGULARITY_OMPI_DIR=/opt/amazon/openmpi
export SINGULARITYENV_APPEND_PATH=/opt/amazon/openmpi/bin
export SINGULAIRTYENV_APPEND_LD_LIBRARY_PATH=/opt/amazon/openmpi/lib

srun singularity exec --nv docker://public.ecr.aws/w6p6i9i7/aws-efa-nccl-rdma:base-cudnn8-cuda11.3-ubuntu20.04 /opt/nccl-tests/build/all_reduce_perf -b 128M -e 8G -f 2 -g 1 -c 1 -n 20
```

2\. Nvidia _enroot/pyxis_ is a containerisation solution combined with a slurm plugin from Nvidia. Unlike Singularity, which AWS does not support, the enroot path is preferred when you ponder what to choose.

Here is how to run something interactive from the HeadNode
```
srun --partition=gpu --nodes=1 --gpus=8 --cpus-per-gpu=6 --container-image=image:tag nvidia-smi
```
will execute nvidia-smi within the container and will return the result in stdout at the HeadNode

With the above information, I was able to run nice-tests also inside both container platforms with indiscernible differences in performance. The containers got marginally better results than the host OS. If you get an interactive prompt inside a compute node, the environment variables will be properly set by the compute node configuration. try this:
```
srun --partition=gpu --nodes=1 --gpus=8 --cpus-per-gpu=6 --pty bash -i
```
How to access AWS baseami ML containers: 
```
--container-image=public.ecr.aws#w6p6i9i7/aws-efa-nccl-rdma:base-cudnn8-cuda11-ubuntu20.04
```

#### Singularity

A good introduction to Singularity can be found at:<https://github.com/bdusell/singularity-tutorial>The documentation for Singularity can be found at:<https://docs.sylabs.io/guides/3.2/user-guide/>

Building Singularity images require sudo access which is not available on the HPC cluster. There are two main ways to get around this:

1. Build the image on your local device, then upload it.

2. Build images remotely. Here is a method:

   1. Get a token from <https://cloud.sylabs.io/tokens>.
   2. Log in to the remote build service with singularity remote login SylabsCloud and enter your token.
   3. Add the --remote flag to your build call. e.g. singularity build --remote ....


### 
### Limitations

#### FSx

As mentioned, FSx is high-speed storage mounted to all nodes. It is also the most expensive, so we must keep it lean. Please follow these rules in dealing with it:

- keep final results out of FSx. Best compress and save to S3
- keep computer vision data out of FSx even for training. By using webdataset format, S3 proves to be 100x faster than the training code requires, so there is a lot of space to manoeuvre by completely avoiding FSx for these kinds of workloads. We will publish the available computer vision datasets together with data loader samples at [Stability-AI/datasets: Rules to maintain datasets with Stability AI infrastructure (github.com)](https://github.com/Stability-AI/datasets)
- FSx data is compressed with the LZ4 algorithm. Please plan a bit more CPU capacity on your jobs to deal with the decompression
- default settings allow anyone to read data from your folder but not to write or delete it. if you need to keep your data secret (of course, administrators still have access), please follow POSIX security and use chmod command appropriately. Here is a decent guide: [Linux permissions: An introduction to chmod | Enable Sysadmin (redhat.com)](https://www.redhat.com/sysadmin/introduction-chmod)


#### Transfer Speed

Certain locations seem to have varying degrees of upload speed to the HPC cluster. For example, in one instance, uploading 7GB of data from Stockholm, Sweden, took roughly 1 hour. If you encounter any such problems, consider using an intermediate transferring point from which you can share a direct download link, such as Dropbox.com.

You can then download this file to the HPC cluster using:wget DIRECT-DOWNLOAD-LINK


#### HeadNode

The headnode is a highly shared system, and we had to come up with quota, and limitations to restrict users do things that can impact anyone else, thus rendering the entire cluster unusable.

1. disk quota was imposed on home folders up to 30GB per user. it is recommended to symlink folders to /fsx, including the ~/.cache one
2. processing quota is computed depending on the overall usage of the node. When many users are active, you may feel the impact of being throttled when demanding high resource usage. using VS Code, for instance, may introduce such high resource usage for you. So best try to use a simple terminal as a headnode client. For people requiring VS Code on the compute node, this makes more sense as the compute node has more resources and is less shared. 
3. VS Code and especially PyCharm use many resources on the remote server. Instead of directly connecting to the host, we suggest this workaround to reduce the impact on the headnode:

Here's a little rsync-based bash function Scott put together that one can run locally to watch one of your local directories for changes (i.e. so you edit code on your laptop). It will auto-push them to headnode when you save changes. This assumes your code on the server is in ~/code (which may symlink to /fsx if you like).

1. Modify to taste. (e.g. if you want a second argument for the destination instead of code/ just use "$2".)
2. \# rsync changes from local to headnode: usage: rsc &lt;dir> (execute from parent of dir)
```
rsc() {

    while inotifywait -r -e modify,create,delete "$1"; do

    rsync -avz --exclude '\*.pth' --exclude wandb --exclude data "$1"/ headnode:code/"$1"

   done

}
```
3. Sample usage: `rsc k-diffusion`. No persistent process running on headnode!


### 
### Example of training script

#### Dalle2 Decoder

<https://gist.github.com/rom1504/474f97a95a526d40ae44a3fc3c657a2e>


#### Open clip

<https://gist.github.com/rom1504/0d6b7e4e49626109a5a8e1c59a4e1aa6> 


#### Scaling performance with pytorch/nccl/efa

![](https://lh4.googleusercontent.com/ftDwEZEHQusvW3Cfjt86Dz2q_yUyOc1Z_qARZApySikM_Ff0WGv51HQfee1f8n2BhOJKvSaOMO3u5PM5QOMespLrh7hjFlkpZNUnakmQTp1uHuOT8GI8N6ahAtygHapJ8y4w-lAquRDKTTx1yNuLPRtpAN466uQRvSe6CYseDr7OWvhv58F2bMNldQ)

<https://docs.google.com/spreadsheets/d/1bt_Rpkb35OIjTH7MLSfAUV5RHOZ_U4nYt74UAlosT2o/edit#gid=0> 

For that to happen, please make sure you use NCCL tree protocol (or leave the default which puts tree with the highest priority), as the ring protocol has reduced performance in our context.


## Appendix 1 - Password complexity requirements

1. Passwords may not contain the user's samAccountName (Account Name) value or entire displayName (Full Name value). Both checks are not case-sensitive.The samAccountName is checked in its entirety only to determine whether it is part of the password. This check is skipped if the samAccountName is less than three characters long.The displayName is parsed for delimiters: commas, periods, dashes or hyphens, underscores, spaces, pound signs, and tabs. If any delimiters are found, the displayName is split, and all parsed sections (tokens) are confirmed not to be included in the password. Tokens that are less than three characters are ignored, and substrings of the tokens are not checked. For example, the name "Erin M. Hagens" is split into three tokens: "Erin", "M", and "Hagens". Because the second token is only one character long, it is ignored. Therefore, this user could not have a password that included either "erin" or "hagens" as a substring anywhere in the password.

2. The password contains characters from three categories:

   1. Uppercase letters of European languages (A through Z, with diacritic marks, Greek and Cyrillic characters)
   2. Lowercase letters of European languages (a through z, sharp-s, diacritic marks, Greek and Cyrillic characters)
   3. Base 10 digits (0 through 9)
   4. Non-alphanumeric characters (special characters) (for example, !, $, #, %)
   5. Any Unicode character categorised as an alphabetic character is not uppercase or lowercase. This includes Unicode characters from Asian languages.


## Appendix 2 - Error wrapper to find defective GPUs/Instances

Please use this wrapper that will report the defective GPUs when there is one encountered.

We need that information to ask AWS to remove the defective hardware from the pool otherwise, we will crash a lot of projects.

You should report the defect to the [Stability AI Help Center ](https://stabilityai.atlassian.net/servicedesk/customer/portals)

Thank you.
```
   except RuntimeError as err:
        import requests
        import datetime
        ts = datetime.datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')+’ UTC’
        resp = requests.get('http&#x3A;//169.254.169.254/latest/meta-data/instance-id')
        print(f'ERROR at {ts} on {resp.text} {device}: {type(err).\_\_name\_\_}: {err}', flush=True)
        raise err
```
### How to report

Please add this information to the support case (pending AWS solution to allow running sudo nvidia-bug-report.sh from user context so we can automate the reporting.

1. the above output, containing instance id, timestamp, cuda id, and hostname, is also important to extract to continue with step 2
2. start a bogus interactive job with **tmux **using the defective hostname like thissrun –partition=gpu –nodelist=&lt;hostname> –exclusive –pty bash -i
3. From the command prompt inside the defective hostname, runsudo nvidia-bug-report.sh and nvidia-smi -q
4. Retrieve and attach the script output to support case
5. Leave the slurm job run indefinitely and exit tmux session

Devops alternative:

from the cluster headnode as ec2-user

1. make sure you have an open support ticket and a special link to upload big files for that ticket
2. cd /fsx/devops
3. nano report.sh and replace the link in the last line with the link from the ticket, leave the filename intact at the end
4. ssh hostname_with_defect_GPU
5. cd /fsx/devops
6. ./report.sh

Sometimes, the GPUs are not defective in the way they will throw exceptions, therefore problems are more difficult to catch

For instance we found a GPU that after some time fell out of specs and became 5x slower than normal. The entire run of 832 GPUs became 3x less efficient because of it.

Here is a code that allows to catch the slow GPUs (maybe combine some data science methods and make an alert to show outlier GPUs)       begin_forward = time.time()
```
        with autocast():
            image_features, text_features, logit_scale = model(images, texts)
            total_loss = loss(image_features, text_features, logit_scale)
        time_forward = time.time() - begin_forward
        hostname = socket.gethostname()
        forward_time_m.update(time_forward)
        if i % 5 ==0:
            logging.info(f"forward took {forward_time_m.val} on {hostname}:{device}")
            forward_time_m.reset()
```
