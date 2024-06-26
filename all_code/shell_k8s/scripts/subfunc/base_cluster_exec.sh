#!/bin/bash
# *************************************
# 功能: Kubernetes集群基础环境
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 版本: v0.1
# 日期: 2023-12-12
# *************************************

# K8s内核参数配置
k8s_kernel_config(){
  # 接收参数
  local ip_list="$1"
  local kernel_conf_file='/etc/sysctl.d/k8s.conf'

  # 执行逻辑
  for ip in ${ip_list};do
    # 文件判断检测
    local kernel_conf_status=$(ssh "${login_user}@${ip}" "[ -f ${kernel_conf_file} ]" \
                             && echo "exist" || echo "nofile")
    if [ "${kernel_conf_status}" == "exist" ]; then
      echo -e "\033[32m主机 ${ip} 内核环境已经设置，无需重复设置!!!\033[0m"
    else
      if [ -f "${scripts_dir}/${base_kernel_scripts}" ]; then
        # 仅向当前节点传递文件即可，而后执行脚本
        scp_file ${ip} "${scripts_dir}/${base_kernel_scripts}" "/tmp/"
        ssh "${login_user}"@"${ip}" "/bin/bash /tmp/${base_kernel_scripts}"
        echo -e "\e[32mK8s ${ip} 节点主机内核参数调整完毕!!!\e[0m"
      else
        echo -e "\e[31m脚本 ${base_kernel_scripts} 文件不存在，请确认!!\e[0m"
      fi
    fi
  done
}

# Containerd环境
cri_containerd_offline(){
  echo "部署containerd的环境"
}

# CRI-O环境部署
cri_crio_offline(){
  echo "部署CRI-O的环境"
}

# Cri-dockerd环境部署
cri_dockerd_offline(){
  # 接收参数
  local ip_list="$1"

  # 执行逻辑
  echo -e "\e[33m开始执行cri服务软件的部署...\e[0m"
  if [ -f "${scripts_dir}/${base_cri_docker_scripts}" ]; then
    source "${scripts_dir}/${base_cri_docker_scripts}" "${ip_list}"
  else
    echo -e "\e[31m脚本 ${base_cri_docker_scripts} 文件不存在，请确认!!\e[0m"
  fi
}

# CRI服务部署
cri_deploy_offline(){
  # 接收参数
  local ip_list="$1"

  # 优化：如果部署的k8s版本大于1.24，则部署cri-服务，否则不部署
  check_num=$(echo "${k8s_version}" | cut -d'.' -f2)
  if [ "${check_num}" -gt "23" ]; then
    case "${default_container_engine_type}" in 
      "docker")
        cri_dockerd_offline "${ip_list}";;
      "cri-o")
        cri_crio_offline "${ip_list}";;
      "containerd")
        cri_containerd_offline "${ip_list}";;
      *)
        echo -e "\e[31m请输入 docker|cri-o|containerd 的选项内容\e[0m";;
    esac
  fi
}
# Docker环境在线部署
docker_deploy_online(){
  # 接收参数
  local ip_list="$1" 
  # 执行逻辑
  if [ -f "${scripts_dir}/${base_docker_scripts}" ]; then
    scp_file ${ip_list} "${scripts_dir}/${base_docker_scripts}" "/tmp/"
    for i in ${ip_list};do
      docker_status=$(ssh "${login_user}"@"${i}" "docker info" 2>/dev/null | grep 'p D' | awk '{print $NF}')
      if [ "${docker_status}" == "systemd" ]; then
        echo -e "\e[32mK8s ${i} 节点主机Docker软件已部署成功\e[0m"
      else
        ssh "${login_user}"@"${i}" "/bin/bash /tmp/${base_docker_scripts}"
        echo -e "\e[32mK8s ${i} 节点主机docker环境部署完毕!!!\e[0m"
      fi
    done
  else
    echo -e "\e[31m脚本 ${base_docker_scripts} 文件不存在，请确认!!\e[0m"
  fi
}
 
# Docker环境离线部署
docker_deploy_offline(){
  # 接收参数
  local ip_list="$1"
  # 执行逻辑
  if [ -f "${scripts_dir}/${base_docker_offline_scripts}" ]; then
    source "${scripts_dir}/${base_docker_offline_scripts}" "${ip_list}"
  else
    echo -e "\e[31m脚本 ${base_docker_offline_scripts} 文件不存在，请确认!!\e[0m"
  fi
} 
 
# Docker环境部署函数
docker_deploy_install(){
  # 接收参数
  local docker_install_type="$1"
  local ip_list="$2"
  
  # docker部署逻辑
  if [ "${docker_install_type}" == "online" ]; then
    echo -e "\e[33m开始以在线方式部署docker软件环境...\e[0m"
    docker_deploy_online "${ip_list}"
    
  else
    echo -e "\e[33m开始以离线方式部署docker软件环境...\e[0m"
    docker_deploy_offline "${ip_list}"
  fi
}
# compose在线部署
compose_install_online(){
  # 判断远程harbor是什么系统类型
  os_type=$(ssh "${login_user}@${harbor_addr}" "grep -i ubuntu /etc/issue" > /dev/null && echo "Ubuntu" || echo "CentOS")
  # 定制软件源更新命令
  if [ "${os_type}" == "Ubuntu" ]; then
    remote_cmd="apt update; apt install ${compose_cmd_name} jq -y" 
  else
    remote_cmd="yum makecache fast; yum install ${compose_cmd_name} jq -y"
  fi
  ssh "${login_user}@${harbor_addr}" "[ ! -f "${compose_bin}" ] && ${remote_cmd}"
}

# compose离线部署
compose_install_offline(){
  # 解压本地文件
  if [ -f "${compose_dir}/${compose_file_name}"  ];then
    scp "${compose_dir}/${compose_file_name}" "${login_user}@${harbor_addr}:${compose_bin_dir}/${compose_cmd_name}"
    ssh "${login_user}@${harbor_addr}" "chmod +x ${compose_bin_dir}/${compose_cmd_name}"
  else
    echo -e "\e[33m没有可用的docker-compose文件, 请提前下载!!!\e[0m"
  fi
}

# 检测compose环境状态
compose_status_check(){
  local compose_bin="${compose_bin_dir}/${compose_cmd_name}"
  local compose_status=$(ssh "${login_user}@${harbor_addr}" " \
                         [ -f ${compose_bin} ] && echo is_exist || echo no_exist")
  echo "${compose_status}"
}

# compose部署检测函数
compose_check(){
  # 获取compose状态
  local compose_status=$(compose_status_check)
  if [ "${compose_status}" == "is_exist" ]; then
    echo -e "\e[32mharbor主机部署 docker-compose 环境成功\e[0m"
  else
    echo -e "\e[31mharbor主机部署 docker-compose 环境失败\e[0m"
  fi 
}

# compose部署总函数
compose_install(){
  # 接收参数
  local compose_install_type="$1"

  # 部署docker-compose之前，检测效果
  local compose_status=$(ssh "${login_user}@${harbor_addr}" "ls ${compose_bin_dir}/${compose_cmd_name}" >/dev/null 2>&1  && echo "exist" || echo "none")
  if [ "${compose_status}" == "exist" ]; then
    echo -e "\e[32mharbor主机 docker-compose 环境已存在!!!\e[0m"
  else
    # 部署docker-compose
    if [ "${compose_install_type}" == "online" ]; then
      # 以在线方式部署compose
      echo -e "\e[33m开始在线方式部署docker-compose环境!!!\e[0m"
      compose_install_online
    else
      # 以离线方式部署compose
      echo -e "\e[33m开始离线方式部署docker-compose环境!!!\e[0m"
      compose_install_offline
    fi
    # 检测docker-compose环境部署效果
    compose_check
  fi
}

# Harbor环境
harbor_deploy_offline(){
  # 接收参数
  local harbor_user="$1"
  local harbor_my_repo="$2"
  local depend_type="$3"
  # 部署docker环境
  # docker_deploy_online "${harbor_addr}" 
  docker_deploy_install "${depend_type}" "${harbor_addr}"
  
  # 部署compose
  compose_install "${depend_type}"
 
  # 执行逻辑
  if [ -f "${scripts_dir}/${base_harbor_install_scripts}" ]; then
    local harbor_addr=$(get_remote_node_name "${harbor_addr}" "long")
    source "${scripts_dir}/${base_harbor_install_scripts}"
    echo "harbor环境部署"
  else
    echo -e "\e[31m脚本 ${base_harbor_install_scripts} 文件不存在，请确认!!\e[0m"
  fi
}
# Keepalived环境

# Haproxy代理环境

# Nginx代理环境

# 在线方式一键集群基础环境
one_key_cluster_env_online(){
  echo -e "\e[33m开始执行K8s内核参数配置...\e[0m"
  k8s_kernel_config "${all_k8s_list}"
  echo -e "\e[33m开始执行docker软件的部署...\e[0m"
  docker_deploy_online "${all_k8s_list}"
  cri_deploy_offline "${all_k8s_list}"
  echo -e "\e[33m开始执行容器镜像仓库部署...\e[0m"
  harbor_deploy_offline "${harbor_user}" "${harbor_my_repo}" "${default_deploy_type}"
  # 判断k8s集群模式和集群类型
  if [ "${cluster_type}" != 'alone' ];then
    echo "执行高可用环境部署"
  fi

}

# 离线方式一键集群基础环境
one_key_cluster_env_offline(){
  echo -e "\e[33m开始执行K8s内核参数配置...\e[0m"
  k8s_kernel_config "${all_k8s_list}"
  echo -e "\e[33m开始执行docker软件的部署...\e[0m"
  docker_deploy_offline "${all_k8s_list}"
  cri_deploy_offline "${all_k8s_list}"
  echo -e "\e[33m开始执行容器镜像仓库部署...\e[0m"
  harbor_deploy_offline "${harbor_user}" "${harbor_my_repo}" "${default_deploy_type}"
  # 判断k8s集群模式和集群类型
  if [ "${cluster_type}" != 'alone' ];then
    echo "执行高可用环境部署"
  fi
}
# 一键集群基础环境
one_key_cluster_env(){
  # 保证一键环境下，harbor地址的正常
  harbor_addr=$(grep register "${host_file}" | awk '{print $2}')
  harbor_url="${harbor_http_type}://${harbor_addr}"

  if [ "${cluster_mode}" == "alone" ]; then
    if [ "${default_deploy_type}" == "online" ]; then
      echo -e "\e[33m开始 以在线方式 部署 单集群 K8s环境...\e[0m"
      one_key_cluster_env_online
    else
      echo -e "\e[33m开始 以离线方式 部署 单集群 K8s环境...\e[0m"
      one_key_cluster_env_offline
    fi
  else
    if [ "${default_deploy_type}" == "online" ]; then
      echo -e "\e[33m开始 以在线方式 部署 多集群 K8s环境...\e[0m"
    else
      echo -e "\e[33m开始 以离线方式 部署 多集群 K8s环境...\e[0m"
    fi
  fi
}
