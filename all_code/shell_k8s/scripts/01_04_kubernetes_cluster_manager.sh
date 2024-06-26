#!/bin/bash
# *************************************
# 功能: Kubernetes集群管理功能
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
source ${subfunc_dir}/${base_func_menu}
source ${subfunc_dir}/${base_func_usage}

# 基础内容
array_target=(管理 清理 网络 存储 基础 资源 退出)

# 主函数
main(){
  while true
  do
    # 打印k8s集群管理菜单
    k8s_cluster_manager
    read -p "请输入您要操作的选项id值: " target_id
    [ -e ${target_id} ] && target_id='100'
    if [ ${#array_target[@]} -ge ${target_id} ]; then
      if [ ${array_target[$target_id-1]} == "管理" ]; then
         echo -e "\e[33m开始执行k8s集群功能管理操作...\e[0m"
         /bin/bash "${scripts_dir}/${k8s_cluster_function_manager_scripts}"
      elif [ ${array_target[$target_id-1]} == "清理" ]; then
         echo -e "\e[33m开始执行k8s集群清理管理操作...\e[0m"
         /bin/bash "${scripts_dir}/${k8s_cluster_clean_manager_scripts}"
      elif [ ${array_target[$target_id-1]} == "网络" ]; then
         echo -e "\e[33m开始执行k8s集群网络管理操作...\e[0m"
         /bin/bash  "${scripts_dir}/${k8s_cluster_network_manager_scripts}"
      elif [ ${array_target[$target_id-1]} == "存储" ]; then
         echo -e "\e[33m开始执行k8s集群存储管理操作...\e[0m"
         /bin/bash "${scripts_dir}/${k8s_cluster_storage_manager_scripts}"
      elif [ ${array_target[$target_id-1]} == "基础" ]; then
         echo -e "\e[33m开始执行k8s集群基础环境管理操作...\e[0m"
         /bin/bash "${scripts_dir}/${k8s_cluster_depend_manager_scripts}"
      elif [ ${array_target[$target_id-1]} == "资源" ]; then
         echo -e "\e[33m开始执行k8s集群资源管理操作...\e[0m"
         /bin/bash "${scripts_dir}/${k8s_cluster_resource_manager_scripts}"
      elif [ ${array_target[$target_id-1]} == "退出" ]; then
         echo -e "\e[33m开始执行K8s集群管理退出操作...\e[0m"
         exit
      fi
    else
      Usage
    fi
  done
}

# 执行主函数
main
