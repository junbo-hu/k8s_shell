#!/bin/bash
# *************************************
# 功能: Shell自动化管理配置基础设施环境
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 版本: v0.1
# 日期: 2023-04-13
# *************************************

# 基本功能
os_type=$(grep -i ubuntu /etc/issue && echo "Ubuntu" || echo "CentOS" )
[ "${os_type}" == "CentOS" ] && cmd_type="yum" || cmd_type="apt-get"
root_dir=$(dirname $PWD)
[ -f $root_dir/conf/config ] && source $root_dir/conf/config || exit

# 加载功能函数
source ${subfunc_dir}/${base_func_menu}
source ${subfunc_dir}/${base_func_usage}
source ${subfunc_dir}/${base_func_exec}

# 基础内容
array_target=(一键 基础 免密码 hosts 主机名 软件源 主机 退出)

# 主函数区域
main(){
  while true
  do
    base_env_menu
    read -p "请输入您要操作的选项id值: " target_id
    [ -e ${target_id} ] && target_id='100'
    if [ ${#array_target[@]} -ge ${target_id} ]; then
      if [ ${array_target[$target_id-1]} == "一键" ];
      then
        echo -e "\e[33m开始执行一键通用基本环境部署...\e[0m"
        one_key_base_env
      elif [ ${array_target[$target_id-1]} == "基础" ]
      then
        echo -e "\e[33m开始执行基本环境部署...\e[0m"
        expect_install
        sshkey_create
        hosts_create
      elif [ ${array_target[$target_id-1]} == "免密码" ]
      then
        echo -e "\e[33m开始执行跨主机免密码认证...\e[0m"
        read -p "请输入您要执行批量认证的主机列表,只需要ip最后一位(示例: {12..20}): " num_list
        ip_list=$(create_ip_list "${target_net}" "${num_list}")
        sshkey_auth_func "${ip_list}"
      elif [ ${array_target[$target_id-1]} == "hosts" ]
      then
        echo -e "\e[33m开始执行同步集群hosts...\e[0m"
        read -p "请输入您要执行同步hosts的主机列表,只需要ip最后一位(示例: {12..20}): " num_list
        ip_list=$(create_ip_list "${target_net}" "${num_list}")
        scp_hosts_file ${ip_list} "${host_file}" "${host_target_dir}"
      elif [ ${array_target[$target_id-1]} == "主机名" ]
      then
        echo -e "\e[33m开始执行设定集群主机名...\e[0m"
        read -p "请输入您要执行批量设定主机名的列表,只需要ip最后一位(示例: {12..20}): " num_list
        ip_list=$(create_ip_list "${target_net}" "${num_list}")
        set_hostname ${ip_list}
      elif [ ${array_target[$target_id-1]} == "软件源" ]
      then
        echo -e "\e[33m开始执行更新软件源...\e[0m"
        read -p "请输入您要执行批量更新软件源主机的列表,只需要ip最后一位(示例: {12..20}): " num_list
        ip_list=$(create_ip_list "${target_net}" "${num_list}")
        repo_update "${ip_list}"
      elif [ ${array_target[$target_id-1]} == "主机" ]
      then
        echo -e "\e[33m开始执行一键部署指定主机通用基础环境操作...\e[0m"
        read -p "请输入您要执行批量更新软件源主机的列表,只需要ip最后一位(示例: {12..20}): " num_list
        ip_list=$(create_ip_list "${target_net}" "${num_list}")
        sshkey_auth_func "${ip_list}"
        scp_file ${ip_list} "${host_file}" "${host_target_dir}"
        set_hostname ${ip_list}
        repo_update "${ip_list}"
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
