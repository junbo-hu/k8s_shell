#!/bin/bash
# *************************************
# 功能: Kubernetes集群存储管理
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
array_target=(nfs ceph longhorn glusterfs moosefs hdfs  退出)

# 主函数
main(){
  while true
  do
    # 打印k8s集群清理管理菜单
    k8s_cluster_storage_manager
    read -p "请输入您要操作的选项id值: " target_id
    [ -e ${target_id} ] && target_id='100'
    if [ ${#array_target[@]} -ge ${target_id} ]; then
      if [ ${array_target[$target_id-1]} == "nfs" ]; then
         echo -e "\e[33m为k8s集群准备NFS存储环境操作...\e[0m"
      elif [ ${array_target[$target_id-1]} == "ceph" ]; then
         echo -e "\e[33mk8s集群准备Ceph存储环境操作...\e[0m"
      elif [ ${array_target[$target_id-1]} == "longhorn" ]; then
         echo -e "\e[33mk8s集群准备Longhorn存储环境操作...\e[0m"
      elif [ ${array_target[$target_id-1]} == "glusterfs" ]; then
         echo -e "\e[33mk8s集群准备GlusterFS存储环境操作...\e[0m"
      elif [ ${array_target[$target_id-1]} == "moosefs" ]; then
         echo -e "\e[33mk8s集群准备MooseFS存储环境操作...\e[0m"
      elif [ ${array_target[$target_id-1]} == "hdfs" ]; then
         echo -e "\e[33mk8s集群准备HDFS存储环境操作...\e[0m"
      elif [ ${array_target[$target_id-1]} == "退出" ]; then
         echo -e "\e[33m开始执行K8s集群存储管理退出操作...\e[0m"
         exit
      fi
    else
      Usage
    fi
  done
}

# 执行主函数
main
