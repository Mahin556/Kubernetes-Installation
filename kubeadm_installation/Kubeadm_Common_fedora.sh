#!/bin/bash
# Author: Mahin Raza
# Date: 2025-6-1
# Description: This script sets up a Kubernetes cluster using kubeadm on Fedora-based systems.
# Version: 1.0.0

###############################################################################################
# USAGE:
# 1. Save this script as `Kubeadm_Common_fedora.sh`.

# 2. Make it executable: `chmod +x Kubeadm_Common_fedora.sh`.

# 3. Run the script with the argument "MASTER", "WORKER" to set up the respective node:  
#    `./Kubeadm_Common_fedora.sh MASTER` or `./Kubeadm_Common_fedora.sh WORKER`.

# 4. Ensure you have root privileges or run with `sudo`.

# 5. This script assumes you are using a Fedora-based system.

# 6. Adjust the HOSTNAME_MASTER and HOSTNAME_WORKER variables as needed.

# 7. Ensure you have internet connectivity for package installations.

# 8. This script is designed to be run on both master and worker nodes.

################################################################################################


# Common Script that execute on Both "Master" & "Worker" Nodes:

# Check if the IP address is valid
ip_Validate() {
    local ip_address="$1"
    echo "Validating IP address: $ip_address"
    sleep 2
    if ! [[ "$ip_address" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "IP address $ip_address is not valid. Please enter a valid IPv4 address."
        exit 1
    else
        echo "IP address $ip_address is valid."
    fi
}

# Check if the IP address is reachable
ping_test() {
    local ip_address="$1"
    echo "Pinging IP address: $ip_address"
    sleep 2
    if ! ping -c 1 "$ip_address" &> /dev/null; then
        echo "The IP address $ip_address is not reachable. Please check the network connection."
        exit 1
    else
        echo "The IP address $ip_address is reachable."
    fi
}

# Check if the IP address is already in /etc/hosts  
# and add it if not present
# This function will add the hostname and IP address to /etc/hosts if it does not already exist
Validate_hosts() {
    local hostname="$1"
    local ip_address="$2"   
    if ! grep -q "$ip_address $hostname.$domain_name $hostname" /etc/hosts; then
        echo "$ip_address $hostname.$domain_name $hostname" | sudo tee -a /etc/hosts > /dev/null
    else
        echo "Entry already exists in /etc/hosts. Skipping..."
    fi
}

# Function to input nodes details
# This function will prompt the user to enter the details of the nodes (hostname and IP address)    
input_nodes() {
    Node_Type="$1"
    echo "Please enter the initial $Node_Type nodes details:"
    count=1
    while true; do
        read -p "Enter the $Node_Type-node-$count hostname (or type 'done' to finish): " hostname
        if [[ "$hostname" == "done" ]]; then
            break
        fi
        read -p "Enter the $Node_Type-node-$count IP address: " ip_address

        # Validate inputs
        if [[ -z "$hostname" ]] && [[ -z "$ip_address" ]]; then
            echo "Hostname and IP address cannot be empty. Please try again."
            continue
        fi
        sleep 1
        ip_Validate "$ip_address"
        sleep 1
        ping_test "$ip_address"    
        sleep 1        
        Validate_hosts "$hostname" "$ip_address"
        ((count++))
    done
}

pre_install() {
    domain_name=""
    local hostname
    local ip_address

    read -p "Enter the domain name for the node (e.g., server.vm): " domain_name
    read -p "Enter the hostname for the node (e.g., master01/worker01): " hostname
    read -p "Enter the IP address for the node: " ip_address

    if [ -z "$domain_name" ]; then
        domain_name="server.vm"  # Default domain name
    fi
  
    # Validate inputs
    if [[ -z "$hostname" ]] && [[ -z "$ip_address" ]]; then
        echo "Hostname and IP address cannot be empty."
        exit 1
    fi

    sleep 1

    # Example usage or returning the values
    echo "Domain: $domain_name"
    echo "Hostname: $hostname"
    echo "IP Address: $ip_address"

    sleep 1
    ip_Validate "$ip_address"
    sleep 1
    ping_test "$ip_address"
    sleep 1
    hostnamectl set-hostname "$hostname.$domain_name"

    # Ensure we have permission to write to /etc/hosts
    if [[ ! -w /etc/hosts ]]; then
        echo "You do not have permission to write to /etc/hosts. Please run this script with sudo."
        exit 1
    fi

    Validate_hosts "$hostname" "$ip_address"

    if [[ $1 == "MASTER" ]];then             
        input_nodes "WORKER"  
    elif [[ $1 == "WORKER" ]]; then
        # For worker nodes, we assume they will connect to the master nodes
        input_nodes "MASTER"  
    fi

    echo "Node preparation complete. Hostname set to $hostname.$domain_name with IP address $ip_address."
          
}

# Check if the script is run with the correct number of arguments
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <MASTER|WORKER>"
    exit 1
fi

NODE=$1

if [[ $NODE == "MASTER" ]];then
    echo "Setting up the Master Node..."
    pre_install $NODE  # Call the function to set up the master node
elif [[ $NODE == "WORKER" ]]; then
    echo "Setting up Worker Node..."
    pre_install $NODE # Call the function to set up the worker node
else
    echo "Invalid argument. Please use 'MASTER' or 'WORKER'."
    exit 1
fi     


# Update the system     
echo "Updating the system..."
sleep 2
sudo dnf update -y > /dev/null

# Install necessary packages
echo "Installing necessary packages..."
sleep 2
sudo dnf install -y vim wget curl net-tools yum-utils > /dev/null

# Disable SELinux: Kubernetes may not work properly with SELinux enabled.
echo "Disabling SELinux..."
sleep 2
sudo setenforce 0 
sudo sed -i --follow-symlinks 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config

# Disable Swap: Required for Kubernetes to function correctly.
echo "Disabling swap..."
sleep 2
sudo swapoff -a
grep -q " swap " /etc/fstab && sudo sed -i.bak -e '/swap/s/^/#/g' /etc/fstab
sleep 2

sudo modprobe overlay
sudo modprobe br_netfilter
sudo modprobe ip_tables
sudo modprobe ip_set

# Load Necessary Kernel Modules: Required for Kubernetes networking.
echo "Loading necessary kernel modules for Kubernetes networking..."
sleep 2
cat >> /etc/modules-load.d/k8s.conf << EOF  
overlay
br_netfilter
ip_tables
ip_set
EOF

# Set Sysctl(kernel) Parameters: Helps with networking.
echo "Setting sysctl parameters for networking..."
sleep 2
cat << EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

# Configure the appropriate firewall rules.
echo "Configuring firewall rules..."
sleep 2
sudo firewall-cmd --permanent --add-protocol=4 > /dev/null
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="10.244.0.0/16" accept' > /dev/null
if [[ "$NODE" == "MASTER" ]]; then
    echo "Configuring firewall rules for Master Node..."
    for port in 6443 2379 2380 10250 10259 10257 179 5473 80 443 53; do
        sudo firewall-cmd --permanent --add-port=$port/tcp > /dev/null
    done
    for port in 5473 51820 4789 53 51821; do
        sudo firewall-cmd --permanent --add-port=$port/udp > /dev/null
    done
    firewall-cmd --reload
else
    echo "Configuring firewall rules for Worker Node..."
    for port in 10250 10255 10256 179 5473 80 443 2379 53; do
        sudo firewall-cmd --permanent --add-port=$port/tcp > /dev/null
    done
    for port in 4789 51820 51821 53 2379; do
        sudo firewall-cmd --permanent --add-port=$port/udp > /dev/null
    done
    sudo firewall-cmd --permanent --add-port=30000-32767/udp > /dev/null
    sudo firewall-cmd --permanent --add-port=30000-32767/tcp > /dev/null
    firewall-cmd --reload
fi


# 4. Install Containerd:
echo "Installing containerd..."
sleep 2
sudo dnf -y install dnf-plugins-core > /dev/null
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo > /dev/null
sudo dnf makecache

sudo dnf -y install containerd.io  > /dev/null
sudo systemctl enable --now containerd 

sudo mkdir -p /etc/containerd
sudo rm -f /etc/containerd/config.toml
sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
# Modify the containerd configuration to use systemd cgroup driver
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml > /dev/null
sudo systemctl restart containerd


# 5. Install Kubernetes Components:
echo "Installing Kubernetes components..."
sleep 2
# Add Kubernetes repository
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF
dnf makecache; dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes > /dev/null
sudo systemctl enable --now kubelet

if [[ $? -eq 0 ]]; then
    echo "Kubernetes components installed successfully."
else
    echo "Failed to install Kubernetes components. Please check the logs."
    exit 1
fi


