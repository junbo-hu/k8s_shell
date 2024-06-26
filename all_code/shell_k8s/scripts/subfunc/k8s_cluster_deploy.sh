#!/bin/bash
# *************************************
# 功能: shell管理k8s集群的各模块一键功能函数
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 版本: v0.1
# 日期: 2023-12-14
# *************************************

# 基本功能
os_type=$(grep -i ubuntu /etc/issue && echo "Ubuntu" || echo "CentOS" )
[ "${os_type}" == "CentOS" ] && cmd_type="yum" || cmd_type="apt-get"

# 一键部署k8s集群
one_key_k8s_cluster_deploy(){
  # 准备相关的基础环境目录
  echo -e "\e[33m开始执行基础环境目录创建...\e[0m"
  offline_dir_create
  # 一键通用基础环境部署
  echo -e "\e[33m开始执行通用基础环境部署...\e[0m"
  one_key_base_env 
  # 一键集群基础环境部署
  echo -e "\e[33m开始执行K8s集群基础环境部署...\e[0m"
  one_key_cluster_env
  # 一键集群初始化操作
  echo -e "\e[33m开始执行K8s环境初始化...\e[0m"
  # 使用全局默认的参数
  onekey_cluster_init "${default_deploy_type}" "${default_repo_type}"
}
