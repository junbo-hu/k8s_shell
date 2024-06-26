#!/bin/bash
# *************************************
# 功能: Kubernetes集群功能管理
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
# 引入三个函数库，目的是定制多文件中的一键功能
source ${subfunc_dir}/${base_cluster_exec}
source ${subfunc_dir}/${k8s_func_exec}
source ${subfunc_dir}/${base_func_image}
source ${subfunc_dir}/${k8s_subfunc_manager}
source ${subfunc_dir}/${k8s_subfunc_clean}

# 基础内容
array_target=(n扩缩 m扩缩 n升级 m升级 证书 备份 还原 一键 退出)

# 主函数
main(){
  while true
  do
    # 打印k8s集群功能管理菜单
    k8s_cluster_function_manager
    read -p "请输入您要操作的选项id值: " target_id
    [ -e ${target_id} ] && target_id='100'
    if [ ${#array_target[@]} -ge ${target_id} ]; then
      if [ ${array_target[$target_id-1]} == "n扩缩" ]; then
        echo -e "\e[33m开始执行k8s集群工作节点扩缩容操作...\e[0m"
        read -p "请输入您要操作节点的动作类型(扩容-out|缩容-in): " opt_type
        [ "${opt_type}" == "in" ] && scale_in_node "reset"
        [ "${opt_type}" == "out" ] && scale_out_node
      elif [ ${array_target[$target_id-1]} == "m扩缩" ]; then
        echo -e "\e[33m开始执行k8s集群控制节点扩缩容操作...\e[0m"
      elif [ ${array_target[$target_id-1]} == "n升级" ]; then
        echo -e "\e[33m开始执行k8s集群工作节点升级操作...\e[0m"
        # 获取k8s的版本信息
        k8s_version_list
        # 确认要更新的k8s版本
        read -t 10 -p "请输入要部署的k8s版本(比如：1.28.1，空表示使用默认值): " version
        [ -z $version ] && update_ver="v${k8s_version}" || update_ver="v${version}"
        read -p "请输入您要更新控制节点的主机地址,只需要ip最后一位(示例: 12): " num_list
        ip_list=$(create_ip_list "${target_net}" "${num_list}")
        k8s_node_update "${version}" "${update_ver}" "${ip_list}"
      elif [ ${array_target[$target_id-1]} == "m升级" ]; then
        echo -e "\e[33m开始执行k8s集群控制节点升级操作...\e[0m"
        # 获取k8s的版本信息
        k8s_version_list
        # 确认要更新的k8s版本
        read -t 10 -p "请输入要部署的k8s版本(比如：1.28.1，空表示使用默认值): " version
        [ -z $version ] && update_ver="v${k8s_version}" || update_ver="v${version}"
        # 确认是否更新k8s的时候，同步更新ETCD
        read -t 10 -p "请确认是否同步更新ETCD环境(true-默认|false): " etcd_update_status
        [ -z $etcd_update_status ] && etcd_update_status="true"
        # 针对乱写的信息，为了安全，设置为同步不更新etcd环境
        [[ "${etcd_update_status}" != "true" || "${etcd_update_status}" != "false" ]] \
                                            && etcd_update_status="false"
        # 根据当前集群类型，确定要更新的节点地址
        if [ "${cluster_type}" == "multi" ]; then
          read -p "请输入您要更新控制节点的主机地址,只需要ip最后一位(示例: 12): " num_list
          ip_list=$(create_ip_list "${target_net}" "${num_list}")
        else
          ip_list=${master1}
        fi
        # 执行k8s集群控制节点更新
        k8s_master_update "${version}" "${update_ver}" "${etcd_update_status}" "${ip_list}"
      elif [ ${array_target[$target_id-1]} == "证书" ]; then
        echo -e "\e[33m开始执行k8s集群证书升级操作...\e[0m"
        read -t 10 -p "请输入要更新k8s集群证书的方式(renew-默认|kubeadm|openssl|none): " cert_update_type
        [ -z ${cert_update_type} ] && cert_update_type="renew"
        k8s_cert_update "${cert_update_type}"
      elif [ ${array_target[$target_id-1]} == "备份" ]; then
        echo -e "\e[33m开始执行k8s集群数据备份操作...\e[0m"
        k8s_data_save
      elif [ ${array_target[$target_id-1]} == "还原" ]; then
        echo -e "\e[33m开始执行k8s集群数据还原操作...\e[0m"
        k8s_data_restore
      elif [ ${array_target[$target_id-1]} == "一键" ]; then
        echo -e "\e[33m开始执行k8s集群一键升级操作...\e[0m"
        # 获取k8s的版本信息
        k8s_version_list
        # 确认要更新的k8s版本
        read -t 10 -p "请输入要部署的k8s版本(比如：1.28.1，空表示使用默认值): " version
        [ -z $version ] && update_ver="v${k8s_version}" || update_ver="v${version}"
        # 确认是否更新k8s的时候，同步更新ETCD
        read -t 10 -p "请确认是否同步更新ETCD环境(true-默认|false): " etcd_update_status
        [ -z $etcd_update_status ] && etcd_update_status="true"
        # 针对乱写的信息，为了安全，设置为同步不更新etcd环境
        [[ "${etcd_update_status}" != "true" || "${etcd_update_status}" != "false" ]] \
                                            &&  etcd_update_status="false"
        k8s_onekey_update "${version}" "${update_ver}" "${etcd_update_status}"
      elif [ ${array_target[$target_id-1]} == "退出" ]; then
        echo -e "\e[33m开始执行K8s集群功能管理退出操作...\e[0m"
        exit
      fi
    else
      Usage
    fi
  done
}

# 执行主函数
main
