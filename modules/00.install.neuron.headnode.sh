#!/bin/bash
# Install Python venv and activate Python virtual environment to install Neuron pip packages.
python3.7 -m venv aws_neuron_venv_pytorch
source aws_neuron_venv_pytorch/bin/activate
python -m pip install -U pip

# Install packages from beta repos

python -m pip config set global.extra-index-url "https://pip.repos.neuron.amazonaws.com"
# Install Python packages
python -m pip install torch-neuronx=="1.11.0.1.*" "neuronx-cc==2.*" 
