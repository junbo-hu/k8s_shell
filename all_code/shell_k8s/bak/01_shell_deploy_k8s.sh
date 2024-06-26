#!/bin/bash
# 描述：Shell 部署 K8s的入口脚本文件
# 版本：v0.1
# 日期：20230317
# 作者：王树森

# 基础内容
array_target=(基础 内核 容器 仓库 高可用 初始化 管理 退出)

# 功能函数区域
menu(){
  echo -e "\033[31m           Shell操作K8s管理平台\033[0m"
  echo -e "\033[32m============================================\033[0m"
  echo -e "\033[32m1: 基础环境部署     2: K8s内核参数配置\033[0m"
  echo -e "\033[32m3: 容器环境部署     4: 容器镜像仓库部署\033[0m"
  echo -e "\033[32m5: 高可用环境部署   6: K8s环境初始化\033[0m"
  echo -e "\033[32m7: K8s环境管理      8: 退出操作\033[0m"
  echo -e "\033[32m============================================\033[0m"
}

Usage(){
  echo "请输入有效的选项id"
}

# 主函数区域
main(){
  read -p "请输入Kubernetes集群主机的操作系统类型(centos-默认|ubuntu):  " os_type
  os_type=${os_type:-centos}
  while true
  do
    menu
    read -p "请输入您要操作的选项id值: " target_id
    if [ ${#array_target[@]} -ge ${target_id} ]; then
      case ${array_target[$target_id-1]} in
        "基础") 
          echo -e "\e[33m开始执行基础环境部署...\e[0m";;
        "内核")
          echo -e "\e[33m开始执行K8s内核参数配置...\e[0m";;
        "容器")
          echo -e "\e[33m开始执行容器环境部署...\e[0m";;
        "仓库")
          echo -e "\e[33m开始执行容器镜像仓库部署...\e[0m";;
        "高可用")
          echo -e "\e[33m开始执行高可用环境部署...\e[0m";;
        "初始化")
          echo -e "\e[33m开始执行K8s环境初始化...\e[0m";;
        "管理")
          echo -e "\e[33m开始执行K8s环境管理...\e[0m";;
        "退出")
          echo -e "\e[33m开始执行退出操作...\e[0m"
	  exit;;
      esac
    else
      Usage
    fi
  done
}

# 调用区域
main

