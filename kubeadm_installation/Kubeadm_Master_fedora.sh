#!/bin/bash
# Author: Mahin Raza
# Date: 2025-6-1
# Description: This script sets up a Kubernetes cluster using kubeadm on Fedora-based systems.
# Version: 1.0.0

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

echo "Pulling necessary container images..."
sudo kubeadm config images pull

echo "Initializing Kubernetes cluster..."
sudo kubeadm init --pod-network-cidr="$IP_ADDRESS/$CIDR"

echo "Setting up kubeconfig for the user..."
mkdir -p "$HOME/.kube"
sudo cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

echo "Installing Calico network add-on..."
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml

if ! curl -fLO https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml; then
    echo "Failed to download Calico custom-resources.yaml"
    exit 1
fi

sed -i "s#cidr: 192\.168\.0\.0/16#cidr: $IP_ADDRESS/$CIDR#g" custom-resources.yaml
kubectl create -f custom-resources.yaml
rm -f custom-resources.yaml

echo "Waiting for Calico pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n calico-system --timeout=180s

echo "Verifying Calico installation..."
if kubectl get pods -n kube-system &> /dev/null; then
    echo "Calico installation successful."
else
    echo "Calico installation failed. Please check the logs."
    exit 1
fi

echo "Token for joining worker nodes to the cluster:"
sudo kubeadm token create --print-join-command
