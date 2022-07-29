# kube_cluster
#spinup cluster on ubuntu using kubeadm, calico, crio
# requirements
1. Virtualbox with 2 interfaces
2. OS Ubuntu 20.04
#script args
#run as root
on all nodes
# ./spincluster.sh base
on master
# ./spincluster.sh master

on worker, run the kubeadm join command prompted during master Configuration.

remove configuration
# ./spincluster.sh destroy
