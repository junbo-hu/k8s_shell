#!/bin/bash
# *************************************
# 功能: Shell脚本模板
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 版本: v0.1
# 日期: 2023-07-08
# *************************************

# 基础环境变量
sysctl_k8s_file='/etc/sysctl.d/k8s.conf'
system_fstab_file='/etc/fstab'

# swap禁用功能函数
swap_deny(){
  # 禁用当前主机的swap功能
  local status=$(swapon -s)
  if [ -n "${status}" ]; then
    swapoff -a
    sed -i '/swap/s/^/#/' "${system_fstab_file}"
  fi

  # 调整swap的内核参数
  echo "vm.swappiness=0" > "${sysctl_k8s_file}"
}

# 网络参数调整函数
network_data_trans(){
  # 调整网络内核参数
  echo "net.bridge.bridge-nf-call-ip6tables = 1" >> "${sysctl_k8s_file}"
  echo "net.bridge.bridge-nf-call-iptables = 1" >> "${sysctl_k8s_file}"
  echo "net.ipv4.ip_forward = 1" >> "${sysctl_k8s_file}"
  # 加载模块
  modprobe br_netfilter
  modprobe overlay
}

# 主函数
main(){
  swap_deny
  network_data_trans
  sysctl -p "${sysctl_k8s_file}"
}

# 执行主函数
main
