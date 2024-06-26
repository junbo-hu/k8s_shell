#!/bin/bash
# *************************************
# 功能: Shell 部署 K8s的入口脚本文件
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 版本: v0.1
# 日期: 2023-04-13
# *************************************

# 加载项目的配置属性信息
root_dir=$(dirname $PWD)
[ -f $root_dir/conf/config ] && source $root_dir/conf/config || exit

# 加载功能函数
source ${subfunc_dir}/${base_func_menu}
source ${subfunc_dir}/${base_func_usage}
source ${subfunc_dir}/${base_func_exec}
source ${subfunc_dir}/${base_cluster_exec}
source ${subfunc_dir}/${k8s_func_exec}
source ${subfunc_dir}/${k8s_cluster_deploy}
source ${subfunc_dir}/${base_func_offline}
source ${subfunc_dir}/${base_func_image}
source ${subfunc_dir}/${k8s_subfunc_network}

# 基础内容
array_target=(一键 基础 集群 初始化 管理 平台方案 平台基础 离线 退出)

# 主函数区域
main(){
  while true
  do
    manager_menu
    read -p "请输入您要操作的选项id值: " target_id
    # bug修复：避免target_id为空的时候，条件判断有误
    [ -e ${target_id} ] && target_id='100'
    if [ ${#array_target[@]} -ge ${target_id} ]; then
      # 增加一键功能执行
      if [ ${array_target[$target_id-1]} == "一键" ]
      then
        echo -e "\e[33m开始执行一键Kubernetes集群部署操作...\e[0m"
        one_key_k8s_cluster_deploy
      elif [ ${array_target[$target_id-1]} == "基础" ] 
      then
        echo -e "\e[33m开始执行通用基础环境部署...\e[0m"
        if [ -f "${scripts_dir}/${base_env_scripts}" ]; then
          /bin/bash  "${scripts_dir}/${base_env_scripts}"
        else
          echo -e "\e[31m脚本 ${base_env_scripts} 文件不存在，请确认!!\e[0m"
        fi
      elif [ ${array_target[$target_id-1]} == "集群" ]
      then
        echo -e "\e[33m开始执行K8s集群基础环境部署...\e[0m"
        if [ -f "${scripts_dir}/${base_cluster_scripts}" ]; then
          /bin/bash -x "${scripts_dir}/${base_cluster_scripts}"
        else
          echo -e "\e[31m脚本 ${base_cluster_scripts} 文件不存在，请确认!!\e[0m"
        fi
      elif [ ${array_target[$target_id-1]} == "初始化" ]
      then
        echo -e "\e[33m开始执行K8s环境初始化...\e[0m"
        /bin/bash "${scripts_dir}/${k8s_cluster_init_scripts}"
      elif [ ${array_target[$target_id-1]} == "管理" ]
      then
        echo -e "\e[33m开始执行K8s集群管理...\e[0m"
        /bin/bash "${scripts_dir}/${k8s_cluster_manager_scripts}"
      elif [ ${array_target[$target_id-1]} == "平台方案" ]
      then
        echo -e "\e[33m开始执行K8s平台方案功能管理...\e[0m"
      elif [ ${array_target[$target_id-1]} == "平台基础" ]
      then
        echo -e "\e[33m开始执行K8s平台基础功能管理...\e[0m"
      elif [ ${array_target[$target_id-1]} == "离线" ]
      then
        echo -e "\e[33m开始执行离线方式部署K8s集群的基础操作...\e[0m"
        /bin/bash "${scripts_dir}/${kubernetes_offline_prepare}"
      elif [ ${array_target[$target_id-1]} == "退出" ]
      then
        echo -e "\e[33m开始执行退出操作...\e[0m"
  exit
      fi
    else
      Usage
    fi
  done
}

# 调用区域
main

