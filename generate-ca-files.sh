#!/bin/bash

# install cfssl
go get -u github.com/cloudflare/cfssl/cmd/...

CERT_DIR=volcano/certs
CA_CONF=ca-config

cfssl gencert -initca ${CA_CONF}/root-csr.json | cfssljson -bare ${CERT_DIR}/root

cfssl gencert -ca=${CERT_DIR}/root.pem -ca-key=${CERT_DIR}/root-key.pem -config=${CA_CONF}/root-ca-config.json \
	kube-apiserver.csr | cfssljson -bare ${CERT_DIR}/kube-apiserver

cfssl gencert -ca=${CERT_DIR}/root.pem -ca-key=${CERT_DIR}/root-key.pem -config=${CA_CONF}/root-ca-config.json \
	admin.csr | cfssljson -bare ${CERT_DIR}/admin

cfssl gencert -ca=${CERT_DIR}/root.pem -ca-key=${CERT_DIR}/root-key.pem -config=${CA_CONF}/root-ca-config.json \
	kube-proxy.csr | cfssljson -bare ${CERT_DIR}/kube-proxy

cfssl gencert -ca=${CERT_DIR}/root.pem -ca-key=${CERT_DIR}/root-key.pem -config=${CA_CONF}/root-ca-config.json \
	kubelet.csr | cfssljson -bare ${CERT_DIR}/kubelet

cfssl gencert -ca=${CERT_DIR}/root.pem -ca-key=${CERT_DIR}/root-key.pem -config=${CA_CONF}/root-ca-config.json \
	controller-manager.csr | cfssljson -bare ${CERT_DIR}/controller-manager

cfssl gencert -ca=${CERT_DIR}/root.pem -ca-key=${CERT_DIR}/root-key.pem -config=${CA_CONF}/root-ca-config.json \
	volcano-scheduler.csr | cfssljson -bare ${CERT_DIR}/volcano-scheduler

