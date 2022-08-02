#!/bin/bash
base_setup () {
#turnoff the swap and update the packages
grep swap /etc/fstab
if [[ $? == 0 ]]; then
	echo "Swap found...disabling swap"
	swapoff -a
	cp -p /etc/fstab /etc/fstab-backup$(date +%F_%R)
	sed -e '/swap/ s/^#*/#/' -i /etc/fstab
else
	:
fi

# Setting up modules

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

# Set up required sysctl params, these persist across reboots.
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

OS=xUbuntu_20.04
VERSION=1.24

# Add Kubic Repo
echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /" | \
tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list

# Import Public Key
curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key | \
apt-key add -

# Add CRI Repo
echo "deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/ /" | \
tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.list

# Import Public Key
curl -L https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$VERSION/$OS/Release.key | \
apt-key add -

apt update
apt install cri-o cri-o-runc cri-tools -y

systemctl enable crio.service
systemctl start crio.service

echo "Checking crio info if it is ready or not"
crictl info

apt -y install curl apt-transport-https
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

apt update
apt -y install vim git curl wget kubelet kubeadm kubectl
#apt-mark hold kubelet kubeadm kubectl
kubectl version --client && kubeadm version
}

master_setup () {
lsmod | grep br_netfilter
systemctl enable kubelet

kubeadm config images pull

kubeadm init --pod-network-cidr=192.168.0.0/16 --upload-certs --control-plane-endpoint=$hostname
}

if [[ $# == 0 ]]; then
	echo "Please provide appropriate arguments"
fi
if [[ $1 == base ]]; then
	echo "Seting up the base packages"
	base_setup
fi
if [[ $1 == master ]]; then
	echo "Setting up masternode"
	master_setup
	mkdir -p $HOME/.kube
        cp -rp /etc/kubernetes/admin.conf $HOME/.kube/config
        chown $(id -u):$(id -g) $HOME/.kube/config
	sleep 20
	kubectl get nodes

	echo "Configuring callico"
#	curl https://docs.projectcalico.org/manifests/calico-typha.yaml -o calico.yaml
#	kubectl apply -f calico.yaml
	kubectl create -f https://docs.projectcalico.org/manifests/tigera-operator.yaml
	kubectl create -f https://docs.projectcalico.org/manifests/custom-resources.yaml
fi
if [[ $1 == worker ]]; then
	echo "Setting up workernode"

fi
if [[ $1 == destroy ]]; then
	echo "Removing packages"
	kubeadm reset
	apt-get purge kubeadm kubectl kubelet kubernetes-cni kube* cri-o cri-o*
fi
