#!/bin/bash
# Author: Mahin Raza
# Date: 2025-6-1
# Description: This script sets up a Kubernetes cluster using kubeadm on Fedora-based systems.
# Version: 0.0.3

# Run this script with the user from which you want to run the kubernetes cluster

# Initializing Kubernetes Control Plane

read -p "Enter the Pod Network CIDR (default:10.244.0.0/16): " input

if [ -z "$input" ]; then
    POD_NETWORK_CIDR="10.244.0.0/16"
else
    POD_NETWORK_CIDR="$input"
fi
IP_ADDRESS=$(echo "$POD_NETWORK_CIDR" | awk -F'/' '{print $1}')
CIDR=$(echo "$POD_NETWORK_CIDR" | awk -F'/' '{print $2}')



# Pulling the necessary container images from the default container registry (usually Docker Hub)
echo "Pulling necessary container images..."
sudo kubeadm config images pull

echo "Initializing Kubernetes cluster..."
sudo kubeadm init --pod-network-cidr=$IP_ADDRESS/$CIDR 

# Set up kubeconfig for the regular user
echo "Setting up kubeconfig for the user..."
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Install a pod network add-on (Calico in this case)
echo "Installing Calico network add-on..."
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml

curl -O -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml

sed -i "s/cidr: 192\.168\.0\.0\/16/cidr: $IP_ADDRESS\/$CIDR/g" custom-resources.yaml # single quotes (') prevent variable expansion in shell. 

kubectl create -f custom-resources.yaml

# Clean up the downloaded file
rm -f custom-resources.yaml

# Wait for the Calico pods to be ready
echo "Waiting for Calico pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n calico-system --timeout=30s

# Verify the installation
echo "Verifying Calico installation..."
kubectl get pods -n kube-system 
if [ $? -eq 0 ]; then
    echo "Calico installation successful."
else
    echo "Calico installation failed. Please check the logs for more details."
fi  

# Get Join Command on Master Node
echo "Token for joining worker nodes to the cluster:"
sudo kubeadm token create --print-join-command