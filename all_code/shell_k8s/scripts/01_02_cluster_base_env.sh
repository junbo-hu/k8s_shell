#!/bin/bash
# *************************************
# 功能: 集群基础环境定制
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 版本: v0.1
# 日期: 2023-12-11
# *************************************

# 加载项目的配置属性信息
root_dir=$(dirname $PWD)
[ -f $root_dir/conf/config ] && source $root_dir/conf/config || exit

# 加载功能函数
source ${subfunc_dir}/${base_func_menu}
source ${subfunc_dir}/${base_func_usage}
source ${subfunc_dir}/${base_func_exec}
source ${subfunc_dir}/${base_cluster_exec}
source ${subfunc_dir}/${base_func_image}

# 自动识别操作系统类型，设定软件部署的命令
status=$(grep -i ubuntu /etc/issue)
[ -n "${status}" ] && os_type="Ubuntu" || os_type="CentOS"

# 基础内容
array_target=(一键 内核 Docker Containerd CRI-O 仓库 Keepalived Haproxy Nginx 退出)

# 主函数区域
main(){
  while true
  do
    # 调用功能菜单函数
    base_cluster_menu
    read -p "请输入您要操作的选项id值: " target_id
    [ -e ${target_id} ] && target_id='100'
    if [ ${#array_target[@]} -ge ${target_id} ]; then
      if [ ${array_target[$target_id-1]} == "一键" ] 
      then
        echo -e "\e[33m开始执行一键集群基础环境部署...\e[0m"  
        one_key_cluster_env
      elif [ ${array_target[$target_id-1]} == "内核" ]
      then
        echo -e "\e[33m开始执行K8s内核参数配置...\e[0m"
        read -p "请输入您要执行k8s内核参数调整的主机列表,只需要ip最后一位(示例: {12..20}): " num_list
        ip_list=$(create_ip_list "${target_net}" "${num_list}")
        k8s_kernel_config "${ip_list}"
      elif [ ${array_target[$target_id-1]} == "Docker" ]
      then
        echo -e "\e[33m开始执行容器环境部署...\e[0m"
        echo -e "\e[33m开始执行docker软件的部署...\e[0m"
        read -p "请输入您要执行docker软件部署的主机列表,只需要ip最后一位(示例: {12..20}): " num_list
        ip_list=$(create_ip_list "${target_net}" "${num_list}")
        read -p "请输入需要部署docker方式的类型(online-默认|offline): " docker_install_type
        [ -n "${docker_install_type}" ] && docker_install_type="${default_deploy_type+${docker_install_type}}" || docker_install_type="${default_deploy_type}"
        docker_deploy_install "${docker_install_type}" "${ip_list}"
        cri_deploy_offline "${ip_list}"
      elif [ ${array_target[$target_id-1]} == "Containerd" ]
      then
        echo -e "\e[33m开始执行Containerd容器环境部署...\e[0m"
      elif [ ${array_target[$target_id-1]} == "CRI-O" ]
      then
        echo -e "\e[33m开始执行CRI-O容器环境部署...\e[0m"
      elif [ ${array_target[$target_id-1]} == "仓库" ]
      then
        echo -e "\e[33m开始执行容器镜像仓库部署...\e[0m"
        read -p "请输入您要确定为harbor主机的地址,只需要ip最后一位(示例: 12): " num
        [ -n "${num}" ] && num_list=$(create_ip_list "${target_net}" "${num}") \
            || num_list=$(awk '/regi/{print $1}' "${host_file}") 
        ip_addr=$(echo "${num_list}" | awk '{print $1}')
        [ -n "${ip_addr}" ] && harbor_addr="${harbor_addr+${ip_addr}}"

        read -p "请您输入harbor依赖环境部署的方式(在线-online|离线-offline):" d_type
        [ -n "${d_type}" ] && depend_type="${default_deploy_type+${d_type}}" || depend_type="${default_deploy_type}"
        read -p "请输入您要为harbor创建的用户名(示例: sswang): " u_harbor
        [ -n "${u_harbor}" ] && harbor_user="${harbor_user+${u_harbor}}"
        read -p "请输入您要为harbor创建的仓库名(示例: sswang): " p_harbor
        [ -n "${p_harbor}" ] && harbor_my_repo="${harbor_my_repo+${p_harbor}}"
        harbor_deploy_offline "${harbor_user}" "${harbor_my_repo}" "${depend_type}"
      elif [ ${array_target[$target_id-1]} == "Keepalived" ]
      then
        echo -e "\e[33m开始执行Keepalived高可用环境部署...\e[0m"
      elif [ ${array_target[$target_id-1]} == "Haproxy" ]
      then
        echo -e "\e[33m开始执行Haproxy反向代理环境部署...\e[0m"
      elif [ ${array_target[$target_id-1]} == "Nginx" ]
      then
        echo -e "\e[33m开始执行Nginx反向代理环境部署...\e[0m"
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

