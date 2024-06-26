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
source ${subfunc_dir}/${k8s_func_exec}
source ${subfunc_dir}/${base_func_image}
source ${subfunc_dir}/${base_cluster_exec}
source ${subfunc_dir}/${k8s_subfunc_manager}
source ${subfunc_dir}/${k8s_subfunc_clean}
source ${subfunc_dir}/${k8s_subfunc_network}

# 基础内容
array_target=(one清 one重 net清理 n清理 m清理 c清理 k清理 r清理 h清理 s清理 退出)

# 主函数
main(){
  while true
  do
    # 打印k8s集群清理管理菜单
    k8s_cluster_clean_manager
    read -p "请输入您要操作的选项id值: " target_id
    [ -e ${target_id} ] && target_id='100'
    if [ ${#array_target[@]} -ge ${target_id} ]; then
      if [ ${array_target[$target_id-1]} == "one清" ]; then
         echo -e "\e[33m开始执行k8s集群一键清理操作...\e[0m"
         read -t 10 -p "请确认清理环境是否同时清理harbor(yes-默认|no): " harbor_clean_status
         [ -z "${harbor_clean_status}" ] && local harbor_clean_status="yes"
         k8s_cluster_one_key_clean "${harbor_clean_status}"
      elif [ ${array_target[$target_id-1]} == "one重" ]; then
         echo -e "\e[33m开始执行k8s集群一键重置操作...\e[0m"
         read -t 10 -p "请确认重置环境是否同时重启主机(yes-默认|no): " host_reboot_status
         [ -z "${host_reboot_status}" ] && local host_reboot_status="yes"
         k8s_cluster_one_key_reset "${host_reboot_status}"
      elif [ ${array_target[$target_id-1]} == "net清理" ]; then
         echo -e "\e[33m开始执行k8s集群网络环境清理操作...\e[0m"
         local current_network_type=$(k8s_cluster_get_network_type)
         echo "k8s集群当前的网络解决方案是: ${current_network_type}"
         read -t 10 -p "请确认是否要清理当前的网络方案(yes|no): " del_net
         [ -z "${del_net}" ] && local del_net="yes"
         if [ "${del_net}" == "yes" ]; then
           k8s_cluster_network_clean "${current_network_type}"
         elif [ "${del_net}" == "no" ]; then
           echo -e "\e[33m暂不删除当前k8s集群的网络解决方案...\e[0m"
         else
           echo -e "\e[31m请不要输入无效的信息...\e[0m"
         fi
      elif [ ${array_target[$target_id-1]} == "n清理" ]; then
         echo -e "\e[33m开始执行k8s集群工作节点清理操作...\e[0m"
         k8s_cluster_worker_node_clean
      elif [ ${array_target[$target_id-1]} == "m清理" ]; then
         echo -e "\e[33m开始执行k8s集群控制节点清理操作...\e[0m"
         k8s_cluster_master_node_remove
      elif [ ${array_target[$target_id-1]} == "c清理" ]; then
         echo -e "\e[33m开始执行k8s集群容器环境清理操作...\e[0m"
         k8s_cluster_node_container_clean
      elif [ ${array_target[$target_id-1]} == "k清理" ]; then
         echo -e "\e[33m开始执行k8s集群内核环境清理操作...\e[0m"
         k8s_cluster_node_sysconf_clean
      elif [ ${array_target[$target_id-1]} == "r清理" ]; then
         echo -e "\e[33m开始执行k8s集群镜像仓库清理操作...\e[0m"
         k8s_cluster_node_harbor_clean
      elif [ ${array_target[$target_id-1]} == "h清理" ]; then
         echo -e "\e[33m开始执行k8s集群高可用环境清理操作...\e[0m"
      elif [ ${array_target[$target_id-1]} == "s清理" ]; then
         echo -e "\e[33m开始执行k8s集群ssh环境清理操作...\e[0m"
         k8s_cluster_node_ssh_clean
      elif [ ${array_target[$target_id-1]} == "退出" ]; then
         echo -e "\e[33m开始执行K8s集群清理管理退出操作...\e[0m"
         exit
      fi
    else
      Usage
    fi
  done
}

# 执行主函数
main
