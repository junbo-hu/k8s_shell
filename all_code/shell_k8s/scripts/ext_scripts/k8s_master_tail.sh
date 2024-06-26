#!/bin/bash
# *************************************
# 功能: Shell脚本模板
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 版本: v0.1
# 日期: 2023-12-02
# *************************************

# k8s集群主节点认证配置
[ -d "$HOME/.kube" ] && rm -rf $HOME/.kube
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 定制k8s集群主节点命令补全动作
grep kubeadm $HOME/.bashrc 2>&1 >>/dev/null && status="ok" || status="no"
[ "${status}" == "no" ] && echo 'source <(kubeadm completion bash)' >> $HOME/.bashrc
grep kubectl $HOME/.bashrc 2>&1 >>/dev/null && status="ok" || status="no"
[ "${status}" == "no" ] && echo 'source <(kubectl completion bash)' >> $HOME/.bashrc
