#!/bin/bash

# Setting-up a network
nmcli connection down ens160
nmcli connection modify ens160 ipv4.addresses 192.168.29.11/24 ipv4.gateway 192.168.29.1 ipv4.method manual
nmcli connection up ens160

echo "IPv4 Gateway : $(ip route get 1.2.3.4 | awk '{print $3}')"
echo "IPv4 Address : $(hostname -I | awk '{print $1}')"
# echo "IPv4 Address : $(ip route get 1.2.3.4 | awk '{print $7}')"
sleep 3

# setting-up a hostname
hostnamectl set-hostname master.server.vm
echo "Hostname : $(hostname)"
sleep 3

###Make DNS local entries - Change it as per your requirement
sudo cat >> /etc/hosts << EOF
192.168.29.11 master.server.vm
192.168.29.12 node1.server.vm
192.168.29.13 node2.server.vm
EOF
echo -e "\nNodes \n$(tail -3 /etc/hosts)\n"
sleep 3


sudo yum install -y kernel-devel-$(uname -r)


sudo modprobe br_netfilter
sudo modprobe ip_vs
sudo modprobe ip_vs_rr
sudo modprobe ip_vs_wrr
sudo modprobe ip_vs_sh
sudo modprobe overlay


sudo cat > /etc/modules-load.d/kubernetes.conf << EOF
br_netfilter
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
overlay
EOF


sudo cat > /etc/sysctl.d/kubernetes.conf << EOF
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system


sudo swapoff -a
sudo sed -e '/swap/s/^/#/g' -i /etc/fstab


### Disable SELINUX ####
#cat /etc/sysconfig/selinux | grep SELINUX=
sudo setenforce 0
sudo sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
echo -e "SELINUX STATUS:\n$(cat /etc/sysconfig/selinux | grep SELINUX=)"



### Docker installation steps 

### Removing the old runtime engine such as Docker and Buildah
#sudo yum -y remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine buildah

# Install the yum-utils package
sudo yum install -y yum-utils

# Add docker repo
sudo yum config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum makecache

# Install Docker packages :docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo containerd config default | sudo tee /etc/containerd/config.tom
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sudo sed -i 's/disabled_plugins = \["cri"]/disabled_plugins = \[""]/g' /etc/containerd/config.toml

# Restarting the docker service and enable it
sudo systemctl enable --now containerd.service
sudo systemctl enable --now docker
# sudo systemctl status containerd.service
# docker run hello-world


### Disable the Firewall ########
sudo systemctl stop firewalld.service
sudo systemctl disable firewalld
# sudo systemctl status firewalld

# if [[ $(systemctl is-active firewalld) == "active" && $(systemctl is-enabled firewalld) == "enabled" ]]; then
#     echo -e "Firewall state: Active\nAfter Boot State: Enabled"
# elif [[ $(systemctl is-active firewalld) == "active" && $(systemctl is-enabled firewalld) == "disabled" ]]; then
#     echo -e "Firewall state: Active\nAfter Boot State: Disabled"
# elif [[ $(systemctl is-active firewalld) == "inactive" && $(systemctl is-enabled firewalld) == "enabled" ]]; then
#     echo -e "Firewall state: Inactive\nAfter Boot State: enabled"
# elif [[ $(systemctl is-active firewalld) == "inactive" && $(systemctl is-enabled firewalld) == "disabled" ]]; then
#     echo -e "Firewall state: Inactive\nAfter Boot State: Disabled"
# else
#     echo "firewalld is failed"
# fi

echo "Firewall Status: Inactive and Disabled"
sleep 3

### Kubernetes installation steps #####

# Creating a Kubernetes repo file
sudo cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni

[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

# Installing the Kubernetes packages : kubelet kubeadm kubectl
sudo dnf makecache; dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

# Enable and start the Kubelet service
sudo systemctl enable --now kubelet.service

# Downloads (pulls) all the necessary container images required for a Kubernetes cluster initialized with kubeadm
sudo kubeadm config images pull

# Initializing Kubernetes Cluster
sudo kubeadm init --pod-network-cidr=192.168.29.0/24
sleep 5

# Setting up Kubernetes access for a user by creating the .kube directory, copying the cluster config, and adjusting ownership for non-root access
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config


### Deploying a Pod network to the cluster. ####
sudo kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml


