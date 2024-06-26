#!/bin/bash
# *************************************
# 功能: Kubernetes集群清理管理
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 版本: v0.1
# 日期: 2024-01-28
# *************************************

# 准备工作
# 加载项目的配置属性信息
root_dir=$(dirname $PWD)
[ -f $root_dir/conf/config ] && source $root_dir/conf/config || exit

# 加载子函数
source ${subfunc_dir}/${base_func_exec}
source ${subfunc_dir}/${base_func_menu}
source ${subfunc_dir}/${base_func_usage}

# 基础内容
array_target=(user ldns conf image https 退出)

# 主函数
main(){
  while true
  do
    # 打印k8s集群清理管理菜单
    k8s_cluster_depend_manager
    read -p "请输入您要操作的选项id值: " target_id
    [ -e ${target_id} ] && target_id='100'
    if [ ${#array_target[@]} -ge ${target_id} ]; then
      if [ ${array_target[$target_id-1]} == "user" ]; then
         echo -e "\e[33m开始执行k8s集群用户管理操作...\e[0m"
      elif [ ${array_target[$target_id-1]} == "ldns" ]; then
         echo -e "\e[33m开始执行k8s集群本地DNS操作...\e[0m"
      elif [ ${array_target[$target_id-1]} == "conf" ]; then
         echo -e "\e[33m开始执行k8s集群组件属性检测操作...\e[0m"
      elif [ ${array_target[$target_id-1]} == "image" ]; then
         echo -e "\e[33m开始执行k8s集群镜像检测操作...\e[0m"
      elif [ ${array_target[$target_id-1]} == "https" ]; then
         echo -e "\e[33m开始执行k8s集群镜像仓库https升级操作...\e[0m"
      elif [ ${array_target[$target_id-1]} == "退出" ]; then
         echo -e "\e[33m开始执行K8s集群依赖管理退出操作...\e[0m"
         exit
      fi
    else
      Usage
    fi
  done
}

# 执行主函数
main
