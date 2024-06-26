#!/bin/bash
# *************************************
# 功能: K8s集群初始化功能脚本
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 版本: v0.1
# 日期: 2023-07-31
# *************************************

# 注意：现阶段，我假设所有的节点类型都是一样的。

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
source ${subfunc_dir}/${k8s_subfunc_network}


# 基础内容
array_target=(一键 软件源 安装 初始化 加入 网络 退出)

# 主函数
main(){
  while true
  do
    # 打印k8s集群初始化菜单
    k8s_init_menu
    read -p "请输入您要操作的选项id值: " target_id
    [ -e ${target_id} ] && target_id='100'
    if [ ${#array_target[@]} -ge ${target_id} ]; then
      if [ ${array_target[$target_id-1]} == "一键" ]; then
         echo -e "\e[33m开始执行一键k8s集群初始化操作...\e[0m"
         read -t 10 -p "请选择以哪种方式部署k8s集群(离线-offline，在线-online): " is_online
         [ -n "${is_online}" ] && is_online="${default_deploy_type+${is_online}}" || is_online="${default_deploy_type}"
         read -t 10 -p "是否使用本地harbor镜像仓库(yes|no): " local_repo
         [ -n "${local_repo}" ] && local_repo="${default_repo_type+${local_repo}}" || local_repo="${default_repo_type}"
         onekey_cluster_init "${is_online}" "${local_repo}"
      elif [ ${array_target[$target_id-1]} == "软件源" ]; then
         echo -e "\e[33m开始执行k8s集群定制软件源操作...\e[0m"
         read -p "请输入您要执行批量软件源定制的列表,只需要ip最后一位(示例: {12..20}): " num_list
         ip_list=$(create_ip_list "${target_net}" "${num_list}")
         create_repo "${ip_list}"
      elif [ ${array_target[$target_id-1]} == "安装" ]; then
         echo -e "\e[33m开始执行k8s集群软件安装操作...\e[0m"
         k8s_version_list
         read -p "请选择以哪种方式部署k8s集群(离线-offline，在线-online): " is_online
         [ -n "${is_online}" ] && is_online="${default_deploy_type+${is_online}}" || is_online="${default_deploy_type}"
         read -p "请输入您要执行批量设定主机名的列表,只需要ip最后一位(示例: {12..20}): " num_list
         ip_list=$(create_ip_list "${target_net}" "${num_list}")
         k8s_install "${is_online}" "${ip_list}"
      elif [ ${array_target[$target_id-1]} == "初始化" ]; then
         echo -e "\e[33m开始执行k8s集群初始化操作...\e[0m"
         read -t 10 -p "是否使用本地harbor镜像仓库(yes|no): " local_repo
         [ -n "${local_repo}" ] && local_repo="${default_repo_type+${local_repo}}" || local_repo="${default_repo_type}"
         read -p "请输入是否需要提前获取镜像文件(yes|no): " is_get_image
         [ -n "${is_get_image}" ] \
              && is_get_image="${default_get_image_type+${is_get_image}}" \
              || is_get_image="${default_get_image_type}"
         read -p "是否使用本地离线镜像文件(yes|no): " is_use_offline_image
         [ -n "${is_use_offline_image}" ] \
              && is_use_offline_image="${default_use_image_type+${is_use_offline_image}}" \
              || is_use_offline_image="${default_use_image_type}"
         get_images "${local_repo}" "${master1}" "${is_get_image}" "${is_use_offline_image}"
         cluster_create "${local_repo}"
         k8s_master_tail 
      elif [ ${array_target[$target_id-1]} == "加入" ]; then
         echo -e "\e[33m开始执行node加入K8s集群操作...\e[0m"
         read -p "请输入需要增加的k8s节点角色(master|node): " host_role
         read -p "请输入需要增加的k8s节点地址ip最后一位(示例: {12..20}): " num_list
         ip_list=$(create_ip_list "${target_net}" "${num_list}")
         add_k8s_node "${host_role}" "${ip_list}"
      elif [ ${array_target[$target_id-1]} == "网络" ]; then
         echo -e "\e[33m开始执行定制K8s集群网络解决方案操作...\e[0m"
         read -p "请输入需要部署的网络解决方案类型(flannel-默认|calico|cilium): " network_type
         [ -n "${network_type}" ] && network_type="${default_network_type+${network_type}}" || network_type="${default_network_type}"
         k8s_network_install "${network_type}"
      elif [ ${array_target[$target_id-1]} == "退出" ]; then
         echo -e "\e[33m开始执行K8s集群初始化退出操作...\e[0m"
         exit
      fi
    else
      Usage
    fi
  done
}

# 执行主函数
main
