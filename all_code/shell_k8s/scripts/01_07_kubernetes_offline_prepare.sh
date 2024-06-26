#!/bin/bash
# *************************************
# 功能: 以离线方式部署k8s集群的准备动作
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 版本: v0.1
# 日期: 2023-12-20
# *************************************

# 加载项目的配置属性信息
root_dir=$(dirname $PWD)
[ -f $root_dir/conf/config ] && source $root_dir/conf/config || exit

# 加载功能函数
source ${subfunc_dir}/${base_func_menu}
source ${subfunc_dir}/${base_func_offline}

# 自动识别部署服务器操作系统类型，设定软件部署的命令
status=$(grep -i ubuntu /etc/issue)
[ -n "${status}" ] && os_type="Ubuntu" || os_type="CentOS"
[ "${os_type}" == "Ubuntu" ] && cmd_type="apt" || cmd_type="yum"

# 基础内容
array_target=(目录 expect docker cridockerd harbor compose k8s 退出)

# 主函数区域
main(){
  while true
  do
    # 调用功能菜单函数
    k8s_offline_menu
    read -p "请输入您要操作的选项id值: " target_id
    [ -e ${target_id} ] && target_id='100'
    if [ ${#array_target[@]} -ge ${target_id} ]; then
      if [ ${array_target[$target_id-1]} == "目录" ]
      then
        echo -e "\e[33m开始执行一键准备目录结构环境操作...\e[0m"
        offline_dir_create
      elif [ ${array_target[$target_id-1]} == "expect" ]
      then
        echo -e "\e[33m开始执行获取expect操作...\e[0m"
        get_offline_expect
      elif [ ${array_target[$target_id-1]} == "docker" ]
      then
        echo -e "\e[33m开始执行获取docker操作...\e[0m"
        read -p "您是否需要指定获取离线的docker版本(yes|no): " get_status
        if [ "${get_status}" == "yes" ]; then
          get_docker_version_online
          docker_arg="${my_ver}"
        else
          docker_arg=${docker_version}
        fi
        get_offline_docker "${docker_arg}"
      elif [ ${array_target[$target_id-1]} == "cridockerd" ]
      then
        echo -e "\e[33m开始执行获取cri-dockerd操作...\e[0m"
        read -p "您是否需要指定获取离线的cri-dockerd版本(yes|no): " get_status
        if [ "${get_status}" == "yes" ]; then
          get_cridockerd_version_online
          cri_dockerd_arg="${my_ver}"
        else
          cri_dockerd_arg=${cri_dockerd_version}
        fi
        get_offline_cridockerd "${cri_dockerd_arg}"
      elif [ ${array_target[$target_id-1]} == "harbor" ]
      then
        echo -e "\e[33m开始执行获取harbor操作...\e[0m"
        read -p "您是否需要指定获取离线的harbor版本(yes|no): " get_status
        if [ "${get_status}" == "yes" ]; then
          get_harbor_version_online
          harbor_arg="${my_ver}"
        else
          harbor_arg=${harbor_version}
        fi
        get_offline_harbor "${harbor_arg}"
      elif [ ${array_target[$target_id-1]} == "compose" ]
      then
        echo -e "\e[33m开始执行获取docker-compose操作...\e[0m"
        read -p "您是否需要指定获取离线的docker-compose版本(yes|no): " get_status
        if [ "${get_status}" == "yes" ]; then
          get_compose_version_online
          compose_arg="${my_ver}"
        else
          compose_arg=${compose_version}
        fi
        get_offline_compose "${compose_arg}"
      elif [ ${array_target[$target_id-1]} == "k8s" ]
      then
        echo -e "\e[33m开始执行获取kubernetes操作...\e[0m"
        read -p "您是否需要指定获取离线的kubernetes版本(yes|no): " get_status
        if [ "${get_status}" == "yes" ]; then
          get_k8s_version
          k8s_arg="${my_ver}"
        else
          k8s_arg=${k8s_version}
        fi
        get_offline_k8s "${k8s_arg}"
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
