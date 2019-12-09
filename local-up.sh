#!/bin/bash

TOP_DIR=/home/k82cn/workspace/src/volcano-ansible
SERVICE_ACCOUNT_KEY=${TOP_DIR}/certs/certs/service-account.key

openssl genrsa -out "${SERVICE_ACCOUNT_KEY}" 2048 2>/dev/null

killall -9 etcd kube-apiserver kube-controller-manager kubelet vc-controllers vc-scheduler vc-admission
rm -f controller-manager.config kubelet.config ${TOP_DIR}/volcano/config/kubelet.config ${TOP_DIR}/volcano/config/controller-manager.config

sleep 10

nohup ${TOP_DIR}/volcano/sbin/etcd \
    --advertise-client-urls="http://192.168.144.88:2379" \
    --listen-client-urls="http://0.0.0.0:2379" \
    --data-dir=${TOP_DIR}/volcano/work/etcd \
    --debug > etcd.log 2>&1 &

nohup ${TOP_DIR}/volcano/sbin/kube-apiserver \
    --logtostderr="false" \
    --log-file=${TOP_DIR}/volcano/logs/kube-apiserver.log \
    --service-account-key-file=${SERVICE_ACCOUNT_KEY} \
    --etcd-servers="http://192.168.144.88:2379" \
    --cert-dir=${TOP_DIR}/certs/certs/ \
    --tls-cert-file=${TOP_DIR}/certs/certs/kube-apiserver.pem \
    --tls-private-key-file=${TOP_DIR}/certs/certs/kube-apiserver-key.pem \
    --client-ca-file=${TOP_DIR}/certs/certs/root.pem \
    --kubelet-client-certificate=${TOP_DIR}/certs/certs/kube-apiserver.pem \
    --kubelet-client-key=${TOP_DIR}/certs/certs/kube-apiserver-key.pem \
    --insecure-bind-address=0.0.0.0 \
    --insecure-port=2000 \
    --secure-port=2001 \
    --storage-backend=etcd3 \
    --feature-gates=AllAlpha=false \
    --service-cluster-ip-range=10.0.0.0/24 &

function setup_kubelet {
    kubectl config set-cluster local --server=https://192.168.144.88:2001 --certificate-authority=${TOP_DIR}/certs/certs/root.pem \
        --kubeconfig ./kubelet.config
    kubectl config set-credentials myself --client-key=${TOP_DIR}/certs/certs/kubelet-key.pem --client-certificate=${TOP_DIR}/certs/certs/kubelet.pem \
        --kubeconfig ./kubelet.config
    kubectl config set-context local --cluster=local --user=myself --kubeconfig kubelet.config
    kubectl config use-context local --kubeconfig kubelet.config
    
    kubectl --kubeconfig ./kubelet.config config view --minify --flatten > ${TOP_DIR}/volcano/config/kubelet.config
}

setup_kubelet

nohup ${TOP_DIR}/volcano/sbin/kubelet \
    --v=4 \
    --logtostderr="false" \
    --log-file=${TOP_DIR}/volcano/logs/kubelet.log \
    --chaos-chance=0.0 \
    --container-runtime=docker \
    --hostname-override=192.168.144.88 \
    --address=192.168.144.88 \
    --kubeconfig ${TOP_DIR}/volcano/config/kubelet.config \
    --feature-gates=AllAlpha=false \
    --cpu-cfs-quota=true \
    --enable-controller-attach-detach=true \
    --cgroups-per-qos=true \
    --cgroup-driver=cgroupfs \
    --eviction-hard='memory.available<100Mi,nodefs.available<10%,nodefs.inodesFree<5%' \
    --eviction-pressure-transition-period=1m \
    --pod-manifest-path=${TOP_DIR}/volcano/static-pods \
    --fail-swap-on=false \
    --authorization-mode=Webhook \
    --authentication-token-webhook \
    --client-ca-file=${TOP_DIR}/certs/certs/root.pem \
    --cluster-dns=10.0.0.10 \
    --cluster-domain=cluster.local \
    --runtime-request-timeout=2m \
    --port=10250 &

function setup_kubectl {
    kubectl config set-cluster local --server=https://192.168.144.88:2001 --certificate-authority=${TOP_DIR}/certs/certs/root.pem
    kubectl config set-credentials myself --client-key=${TOP_DIR}/certs/certs/admin-key.pem --client-certificate=${TOP_DIR}/certs/certs/admin.pem
    kubectl config set-context local --cluster=local --user=myself
    kubectl config use-context local 
}

setup_kubectl

function setup_controller_manager {
    kubectl config set-cluster local --server=https://192.168.144.88:2001 --certificate-authority=${TOP_DIR}/certs/certs/root.pem \
        --kubeconfig ./controller-manager.config
    kubectl config set-credentials myself --client-key=${TOP_DIR}/certs/certs/controller-manager-key.pem \
        --client-certificate=${TOP_DIR}/certs/certs/controller-manager.pem --kubeconfig ./controller-manager.config
    kubectl config set-context local --cluster=local --user=myself --kubeconfig controller-manager.config
    kubectl config use-context local --kubeconfig controller-manager.config
    
    kubectl --kubeconfig ./controller-manager.config config view --minify --flatten > ${TOP_DIR}/volcano/config/controller-manager.config
}

setup_controller_manager

nohup ${TOP_DIR}/volcano/sbin/kube-controller-manager \
    --v=3 \
    --logtostderr="false" \
    --log-file=${TOP_DIR}/volcano/logs/kube-controller-manager.log \
    --service-account-private-key-file=${SERVICE_ACCOUNT_KEY} \
    --root-ca-file=${TOP_DIR}/certs/certs/root.pem \
    --cluster-signing-cert-file=${TOP_DIR}/certs/certs/root.pem \
    --cluster-signing-key-file=${TOP_DIR}/certs/certs/root-key.pem \
    --enable-hostpath-provisioner=false \
    --pvclaimbinder-sync-period=15s \
    --feature-gates=AllAlpha=false \
    --kubeconfig ${TOP_DIR}/volcano/config/controller-manager.config \
    --use-service-account-credentials \
    --controllers=* \
    --leader-elect=false \
    --cert-dir=${TOP_DIR}/certs/certs &


# vc-controllers
nohup ${TOP_DIR}/volcano/sbin/vc-controllers \
    --v=3 \
    --logtostderr=false \
    --log-dir=${TOP_DIR}/volcano/logs/ \
    --scheduler-name=default \
    --kubeconfig=${TOP_DIR}/volcano/config/controller-manager.config &


# vc-scheduler
# vc-admission

