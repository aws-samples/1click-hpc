#!/bin/bash

cat > jupyter.batch << EOF
#!/bin/bash
#SBATCH --job-name=jupyter
#SBATCH --partition=compute-od-jupyter
#SBATCH --gres=gpu:1
#SBATCH --time=2-00:00:00
#SBATCH --output=%x_%j.out

cat /etc/hosts
python3.8 -m pip install notebook
jupyter notebook --ip=0.0.0.0 --port=8888
EOF

cat > py_control.py << EOF
import os

# get slurm job ID
jobId = os.popen('sbatch jupyter.batch').read()
jobId = [int(s) for s in txt.split() if s.isdigit()][0]

# wait until notebook server is started
os.system('( tail -f -n0 jupyter_$jobId & ) | grep -q "http://127.0.0.1"')

# extract compute node IP
jIP = '172.31.0.0'

# extract jupyter notebook token
token = 5a8e2f96e15ef2113d326b02eeb3dc5b83aaba65eaa3b736

echo "ssh with 'ssh -L8888:$jIP:8888 ec2-user@52.71.232.47'"

echo "then visit http://127.0.0.1:8888/?token=$token"
EOF

python3 py_control.py
