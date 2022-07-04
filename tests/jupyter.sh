cat > jupyter.batch << EOF
#!/bin/bash
#SBATCH --job-name=jupyter
#SBATCH --partition=compute-od-jupyter
#SBATCH --gres=gpu:1
#SBATCH --time=2-00:00:00
#SBATCH --output=%x_%j.out

cat /etc/hosts
jupyter lab --ip=0.0.0.0 --port=8888
EOF

