#!/bin/bash

hostnamectl set-hostname node1.server.vm
echo "Hostname : $(hostname)"
sleep 3

### Make DNS local entries ### Change it as per your requirement #####
sudo cat >> /etc/hosts << EOF
192.168.29.11 master.server.vm
192.168.29.236 node1.server.vm
192.168.29.13 node2.server.vm
EOF
echo -e "\nNodes \n$(tail -3 /etc/hosts)\n"
sleep 3

sudo dnf install -y kernel-devel-$(uname -r)

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


### Preparation for Docker installation #########
### Docker installation steps #######
# sudo yum -y remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine buildah
sudo yum install -y yum-utils
sudo yum config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum makecache

sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sudo sed -i 's/disabled_plugins = \["cri"]/disabled_plugins = \[""]/g' /etc/containerd/config.toml

sudo systemctl enable --now containerd.service
sudo systemctl enable --now docker
# sudo systemctl status containerd.service
# docker run hello-world


### Disable the Firewall ########
sudo systemctl stop firewalld.service
sudo systemctl disable firewalld
# sudo systemctl status firewalld
echo "Firewall Status: Inactive and Disabled"
sleep 3

### Kubernetes installation steps #####
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

### Installing the kubelet kubeadm and kubectl
sudo dnf makecache; dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
sudo systemctl enable --now kubelet.service

sleep 3
echo "joining to the cluster"
sleep 3

# kubeadm join master_node_ip:port_open_at_master --token ********* command need to be add
kubeadm join 192.168.29.11:6443 --token lvpo4l.4l0xeeacxe6bz6fa --discovery-token-ca-cert-hash sha256:1143f35e444e77cc66a957046cd750adf30d5ea5c7152fe251ad1b77ae50e1c2
