#!/bin/bash
# *************************************
# 功能: 清理k8s集群环境功能函数库
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 版本: v0.1
# 日期: 2024-04-18
# *************************************


# 获取当前集群网络解决方案类型
k8s_cluster_get_network_type(){
  # 获取集群网络类型
  local current_network_type=$(ssh "${login_user}@${master1}" "ifconfig" \
                              | grep flags | grep -Ev 'eth|ens|cni|lo|veth|docker|cali' \
                              | awk -F'[.|0]' '{print $1}')
  # 定制删除calico的网络方案名字
  [ "${current_network_type}" == "tunl" ] && current_network_type="calico"

  # 输出当前的网络解决方案名字
  echo "${current_network_type}"
}

# 检测当前网络解决方案的配置文件函数
k8s_cluster_network_config_yaml_check(){
  # 获取参数
  local remote_path_to_yaml="$1"

  # 检测yaml文件是否存在
  local network_conf_status=$(ssh "${login_user}@${master1}" \
                            [ -f "${remote_path_to_yaml}" ] \
                            && echo "exist" || echo "noexist" )
  echo "${network_conf_status}"
}

# 当前集群网络环境清理后的检测函数
k8s_cluster_network_del_logic(){
  # 接收参数
  local current_network_type="$1"
  # 等待10s后，检测网络状态
  sleep 5
  # 定制删除网络解决方案的逻辑
  case "${current_network_type}" in
    "flannel")
      # k8s_cluster_network_flannel_status
      k8s_cluster_network_del_status "${current_network_type}" \
                                     "${flannel_ns}" "${flannel_ds_name}"
      ;;
    "calico")
      k8s_cluster_network_del_status "${current_network_type}" \
                                     "${calico_ns}" "${calico_ds_name}"
      ;;
    "cilium")
      echo "清理cilium网络";;
    *)
      echo -e "\e[31m当前网络解决方案，不在清理范围中，请重试!!!\e[0m";;
  esac
}

# 网络环境清理后的检测函数
k8s_cluster_network_del_status(){
  # 接收参数
  local current_network_type="$1"
  local network_ns="$2"
  local network_ds_name="$3"

  # 获取当前的网络方案状态
  local current_network_status=$(k8s_network_status_check "${network_ns}" "${network_ds_name}")

  # 判断网络环境清理后续动作
  if [ "${current_network_status}" == "notrun" ]; then
    # 网络环境删除成功，可以执行后续环境配置清理动作
    for ip in ${all_k8s_list}; do
      k8s_cluster_network_del_tail "${ip}" "${current_network_type}"
    done
    echo -e "\e[32m当前k8s集群 ${current_network_type} 网络环境清理完毕!!!\e[0m"
  else
    echo -e "\e[31m当前k8s集群 ${current_network_type} 网络环境清理失败，请自行确认效果!!!\e[0m"
  fi
}

# 当前集群网络环境清理收尾动作函数
k8s_cluster_network_del_tail(){
  # 接收参数
  local ip_addr="$1"
  local current_network_type="$2"

  # 1 进行网络环境的配置文件删除动作
  case "${current_network_type}" in
    "flannel")
      ssh "${login_user}@${ip_addr}" "rm -rf ${cni_conf_dir}/*"
      ;;
    "calico")
      ssh "${login_user}@${ip_addr}" "rm -rf ${cni_conf_dir}/* /var/lib/cni/* \
                                      /var/log/calico/* /var/lib/calico/*"
      ;;
    "cilium")
      echo "清理cilium网络";;
    *)
      echo -e "\e[31m当前网络解决方案，不在清理范围中，请重试!!!\e[0m";;
  esac

  # 2 对远程主机的网络运行环境进行重置
  ssh "${login_user}@${ip_addr}" "reboot"
}

# 移除网络环境函数
k8s_cluster_network_clean(){
  # 接收参数
  local current_network_type="$1"
  # 定制删除网络解决方案的逻辑
  case "${current_network_type}" in
    "flannel")
      local remote_path_to_file="${remote_dir}/flannel/${flannel_yaml}"
      k8s_cluster_network_clean_logic "${current_network_type}" \
                                      "${remote_path_to_file}" "${flannel_ns}"
      ;;
    "calico")
      local remote_path_to_file="${remote_dir}/calico/${calico_yaml}"
      k8s_cluster_network_clean_logic "${current_network_type}" \
                                      "${remote_path_to_file}" "${calico_ns}"
      ;;
    "cilium")
      echo "清理cilium网络";;
    *)
      echo -e "\e[31m当前网络解决方案，不在清理范围中，请重试!!!\e[0m";;
  esac
}

# 删除网络环境逻辑函数
k8s_cluster_network_clean_logic(){
  # 获取参数
  local current_network_type="$1"
  local remote_path_to_yaml="$2"
  local current_network_ns="$3"
  
  # 1 检测集群网络解决方案的yaml文件状态
  local network_yaml_status=$(k8s_cluster_network_config_yaml_check "${remote_path_to_yaml}")
 
  if [ "${network_yaml_status}" == "exist" ] ; then
    # 2 yaml文件方式清理集群网络
    ssh "${login_user}@${master1}" "kubectl delete -f ${remote_path_to_yaml}"
  else
    # 3 ns删除方式清理集群网络
    ssh "${login_user}@${master1}" "kubectl delete ns ${current_network_ns} --force"
  fi
  
  # 4 集群网络解决方案清理收尾动作
  k8s_cluster_network_del_logic "${current_network_type}"
}

# 对工作节点列表临时文件进行处理
k8s_cluster_node_get_update(){
  # 接收参数
  local temp_node_list_file="$1"
  
  # 完善文件内容
  for i in $(awk 'NR>=2{print $1}' ${temp_node_list_file});do
    ipaddr=$(grep "$i" "${host_file}" | awk '{print $1}')
    sed -i "/$i/s/$/&  $ipaddr/" ${temp_node_list_file}
  done
}

# 获取当前集群的工作节点列表
k8s_cluster_nodes_get(){
  # 定制临时数据文件
  local temp_node_list_file="$1"

  # 到远程主机获取节点信息
  [ -f "${temp_node_list_file}" ] && > "${temp_node_list_file}" || touch "${temp_node_list_file}"
  ssh "${login_user}@${master1}" "kubectl get nodes" 2>/dev/null > "${temp_node_list_file}"

  # 对工作节点列表临时文件进行处理
  k8s_cluster_node_get_update "${temp_node_list_file}"
}

# awk方式格式化输出节点列表
k8s_cluster_node_print(){
  # 定制临时数据文件
  local temp_node_list_file="$1"

  # awk格式化输出信息
  awk '
    function print_title(){
         printf "                           %25s\n","当前集群节点列表"
    }
    function print_line(){
         printf "-----------------------------------------------------------------------\n"
    }
    function print_header(){
         printf "|%4s|%25s|%19s|%10s|%10s|%10s|\n","序号","节点名称","节点地址","节点状态","软件版本","节点角色"
    }
    function print_body(arg1,arg2,arg3,arg4,arg5,arg6){
         printf "|%4s|%21s|%15s|%8s|%8s|%10s|\n",arg1,arg2,arg3,arg4,arg5,arg6
    }
    function print_end(arg1){
         printf "|k8s集群节点数量:   %-50s|\n",arg1
    }
    BEGIN{
      print_title();
      print_line();
      print_header();
      print_line();
      node_num=0
    } NR>=2,$1~"master"?type="控制节点":type="工作节点" {
      node_num+=1;
      print_body(node_num,$1, $NF, $2, $(NF-1), type);
    }
    END{
      print_line();
      print_end(node_num);
      print_line();
    }
  ' ${temp_node_list_file}
}

k8s_cluster_node_print_from_hosts(){
  # 定制临时数据文件
  local temp_node_list_file="$1"
  
  # 定制hosts文件格式打印
  awk '
    function print_title(){
         printf "                           %25s\n","当前集群节点列表"
    }
    function print_line(){
         printf "-----------------------------------------------------------------------\n"
    }
    function print_header(){
         printf "|%4s|%35s|%24s|%15s|\n","序号","节点名称","节点缩写","节点地址"
    }
    function print_body(arg1,arg2,arg3,arg4){
         printf "|%4s|%31s|%20s|%11s|\n",arg1,arg2,arg3,arg4
    }
    function print_end(arg1){
         printf "|k8s集群节点数量:   %-50s|\n",arg1
    }
    BEGIN{
      print_title();
      print_line();
      print_header();
      print_line();
      node_num=0
    } $2~"kube" {
      node_num+=1;
      print_body(node_num,$2,$NF, $1);
    }
    END{
      print_line();
      print_end(node_num);
      print_line();
    }
  ' ${temp_node_list_file}
}

# 格式化输出当前集群的节点列表
k8s_cluster_nodes_list(){
  # 定制临时数据文件
  local temp_node_list_file="$1"
  
  # 获取当前集群的工作节点列表
  k8s_cluster_nodes_get "${temp_node_list_file}"

  # 格式化输出k8s集群节点列表信息
  k8s_cluster_node_print "${temp_node_list_file}"
}

# 判断待删除节点的状态
# k8s_cluster_nodes_status_check(){
# }

# 在线方式节点移除k8s软件
k8s_cluster_nodes_softs_remove_online_logic(){
  # 接收参数
  local cmd_type="$1"
  local remote_addr="$2"

  # 清理节点软件
  ssh "${login_user}@${remote_addr}" "${cmd_type} --purge remove -y kubeadm kubelet kubectl; \
                                      ${cmd_type} -y autoremove"
}

# 离线方式节点移除k8s软件
# k8s_cluster_nodes_softs_remove_offline_logic(){
# }

# 删除工作节点软件环境
k8s_cluster_nodes_softs_remove(){
  # 接收参数
  local remote_addr="$1"

  # 待完善点：离线安装方式的移除逻辑
  if [ "${default_deploy_type}" == "online" ]; then
    # 判断远程主机软件操作命令
    local cmd_type=$(get_remote_cmd_type "remote" "${remote_addr}")
    # 执行远程主机软件删除动作
    k8s_cluster_nodes_softs_remove_online_logic "${cmd_type}" "${remote_addr}"
  elif ["${default_deploy_type}" == "offline"]; then
    echo "以离线的方式移除软件"
  fi
}

# 移除远程主机的软件源文件
delete_remote_node_repo_file(){
  # 接收参数
  local remote_addr="$1"

  # 判断远程主机软件操作系统类型 
  local os_type=$(get_remote_os_type "remote" "${remote_addr}")
  
  # 移除远程主机的软件源文件
  if [ "${os_type}" == "CentOS" ];then
    local k8s_repo_file="${centos_repo_dir}/${centos_repo_file}"
  elif [ "${os_type}" == "Ubuntu" ];then
    local k8s_repo_file="${ubuntu_repo_dir}/${ubuntu_repo_file}"
  fi
  ssh "${login_user}@${remote_addr}" "rm -f ${k8s_repo_file}"
  
}

# 更新远程主机的软件源环境
update_remote_node_repo_env(){
  # 接收参数
  local remote_addr="$1"

  # 判断远程主机软件操作系统类型
  local os_type=$(get_remote_os_type "remote" "${remote_addr}")
  local cmd_type=$(get_remote_cmd_type "remote" "${remote_addr}")

  if [ "${os_type}" == "CentOS" ];then
    local repo_update_cmd="${cmd_type} makecache fast"
  elif [ "${os_type}" == "Ubuntu" ];then
    local repo_update_cmd="${cmd_type} update"
  fi
  # 更新远程主机的软件源环境
  ssh "${login_user}@${remote_addr}" "${repo_update_cmd}"

}

# 清理工作节点软件源环境
k8s_cluster_nodes_repo_remove(){
  # 接收参数
  local remote_addr="$1"

  # 移除远程主机的软件源文件
  delete_remote_node_repo_file "${remote_addr}"

  # 更新远程主机的软件源环境
  update_remote_node_repo_env "${remote_addr}"
}

# 清理集群工作节点函数
k8s_cluster_worker_node_clean(){
  # 从集群中移除指定节点,同时清理节点软件
  scale_in_node "remove"
}

# 自动清理所有的集群工作节点环境函数
k8s_cluster_nodes_clean_auto(){
  # 接收参数
  local host_reboot_status="$1"
  local scale_type="$2"
 
  # 检测集群工作节点的清理状态
  local clean_node_status=$(grep node "${temp_node_list_file}" >/dev/null && echo "exist" || echo "none")
  if [ "${clean_node_status}" == "exist" ]; then
    # 自动清理所有的工作节点
    local all_node=$(awk -F'.' '/node/{print $NF}' "${temp_node_list_file}")
    use_ip_method_scale_in_node "${all_node}" "${host_reboot_status}" "${scale_type}"

    # 检测集群工作节点的清理状态
    k8s_cluster_nodes_get "${temp_node_list_file}"
    local clean_node_status=$(grep node "${temp_node_list_file}" >/dev/null && echo "exist" || echo "none")
    if [ "${clean_node_status}" == "none" ];then
      echo -e "\e[32m当前k8s集群工作节点全部清理完毕...\e[0m"
    else
      echo -e "\e[31m当前k8s集群工作节点全部清理异常，请手工监测...\e[0m"
    fi
  else
    echo -e "\e[32m当前k8s集群不存在任何工作节点,请继续...\e[0m"
  fi
}

# 自动清理所有的集群工作节点环境函数
k8s_cluster_master_clean_auto(){
  # 接收参数
  local host_reboot_status="$1"
  local scale_type="$2"
  
  # 暂且考虑单主master场景，多主master场景之后再说
  # 自动清理所有的工作节点
  local num_list=$(echo "${master1}" | awk -F'.' '{print $NF}')
  use_ip_method_scale_in_node "${num_list}" "${host_reboot_status}" "${scale_type}"
}

# 清理集群控制节点函数
k8s_cluster_master_node_remove(){

  # 获取当前节点的状态信息
  local temp_node_list_file="/tmp/k8s_node.txt"
  k8s_cluster_nodes_get "${temp_node_list_file}"

  # 获取当前集群的类型
  if [ "${cluster_type}" == "alone" ]; then
    echo -e "\e[33m开始清理单主分布式k8s集群的控制节点操作...\e[0m"
    read -t 10 -p "请确认是否在清理master节点的时候，自动备份数据(yes|no): " is_backup_etcd
    [ -z "${is_backup_etcd}" ] && local is_backup_etcd="yes"

    # 1 确保所有的工作节点清理完毕
    #   节点清理完毕后，重启主机
    k8s_cluster_nodes_clean_auto "yes" "remove"

    # 2 是否需要备份数据
    [ "${is_backup_etcd}" == "yes" ] && k8s_data_save

    # 3 清理master节点集群环境
    k8s_cluster_reset_node_logic "master" "${master1}"
   
    # 4 进行远程主机的软件清理动作
    k8s_cluster_nodes_softs_remove "${master1}"
    
    # 5 进行远程主机的软件源清理动作
    k8s_cluster_nodes_repo_remove "${master1}"
    
    # 6 重启master主机
    remote_host_is_reboot "yes" "${master1}"
  else
    echo "按照多主master清理节点"
  fi
}


# 检测远程主机docker环境是否存在
remote_node_service_status_check(){
  # 接收参数
  local remote_addr="$1"
  local service_name="$2"
  
  # 检测服务环境是否正常
  local remote_service_status=$(ssh "${login_user}@${remote_addr}" \
                                "systemctl is-active ${service_name}")
  echo "${remote_service_status}"
}

# 清理cri-dockerd环境
cri_service_dockerd_clean(){
  # 接收参数
  local remote_addr="$1"
  
  # 获取远程主机cri-dockerd状态
  local remote_cri_status=$(remote_node_service_status_check "${remote_addr}" "cri-dockerd.service")
  if [ "${remote_cri_status}" == "active" ]; then
    # 清理节点cri环境
    ssh "${login_user}@${remote_addr}" "systemctl disable --now cri-dockerd.service; \
                                        systemctl stop cri-dockerd.service; \
                                        rm -f ${cri_service_conf} ${cri_socket_conf} ${service_bin_dir}/${cri_name}"
    echo -e "\e[32m节点${remote_addr}移除cri-dockerd环境成功!!!\e[0m"
  else
    echo -e "\e[33m节点${remote_addr}没有cri-dockerd环境!!!\e[0m"
  fi
}

# 清理docker环境
container_service_docker_clean(){
  # 接收参数
  local remote_addr="$1"
  
  # 获取远程主机docker状态
  local remote_dockerd_status=$(remote_node_service_status_check "${remote_addr}" "docker.service")
  if [ "${remote_dockerd_status}" == "active" ]; then
    # 获取当前容器环境的部署方式
    if [ "${default_deploy_type}" == "online" ]; then
      
      # 判断远程主机软件操作命令
      local cmd_type=$(get_remote_cmd_type "remote" "${remote_addr}")
      
      # 清理节点容器环境
      ssh "${login_user}@${remote_addr}" "systemctl disable docker.service containerd.service; \
                                         systemctl stop docker.service containerd.service; \
                                         ${cmd_type} --purge remove -y docker docker-ce docker-ce-cli containerd.io; \
                                         ${cmd_type} -y autoremove"
    else
      echo "离线方式移除docker"
    fi
    echo -e "\e[32m节点${remote_addr}移除dockerd环境成功!!!\e[0m"
  else
    echo -e "\e[33m节点${remote_addr}没有dockerd环境!!!\e[0m"
  fi
}

# 基于IP地址方式移除容器环境
use_ip_method_clean_node_container(){
  # 接收参数
  local num_list="$*"
  local host_list=$(create_ip_list "${target_net}" "${num_list}")

  # 移除节点容器环境
  for ip in ${host_list}; do
    # 清理cri-dockerd环境
    cri_service_dockerd_clean "${ip}"
    # 清理docker环境
    container_service_docker_clean "${ip}"
    echo -e "\e[32m节点${ip}清理容器环境成功!!!\e[0m"
  done
}

# 基于主机名方式移除容器环境
use_hostname_method_clean_node_container(){
  # 接收参数
  local node_name="$1"
  
  # 清理cri-dockerd环境
  cri_service_dockerd_clean "${node_name}"
  # 清理docker环境
  container_service_docker_clean "${node_name}"
}

# 移除容器环境
k8s_cluster_node_container_clean(){
  # 获取节点信息
  k8s_cluster_node_print_from_hosts "${host_file}"

  # 定制要缩容的基本信息
  read -p "请输入您要删除容器环境所在节点的方式(iptail|hostname|k8s|all): " node_delete_type
  if [ "${node_delete_type}" == "iptail" ]; then
    read -p "请输入您要删除节点的列表,只需要ip最后一位(示例: {12..20}): " num_list
    # 基于IP地址的节点缩容
    use_ip_method_clean_node_container "${num_list}"
    # scale_in_node_logic_use_ip "${num_list}"
  elif [ "${node_delete_type}" == "hostname" ]; then
    read -p "请输入您要删除节点的主机名(示例: kubernetes-node): " delete_node_hostname
    # 待完善:
    use_hostname_method_clean_node_container "${delete_node_hostname}"
  elif [ "${node_delete_type}" == "k8s" ]; then
    echo -e "\e[33m清理所有k8s集群节点的容器环境...\e[0m"
    local all_k8s_node=$(awk -F'[.| ]' '/master|node/{print $4}' "${host_file}")
    use_ip_method_clean_node_container "${all_k8s_node}"
  elif [ "${node_delete_type}" == "all" ]; then
    local all_node=$(awk -F'[.| ]' '/kube/{print $4}' "${host_file}")
    use_ip_method_clean_node_container "${all_node}"
  else
    echo -e "\e[31m请输入有效的节点移除方式\e[0m"
  fi 
}

# 基于IP地址方式移除内核参数环境
use_ip_method_clean_sysconf_env(){
  # 接收参数
  local num_list="$*"
  local host_list=$(create_ip_list "${target_net}" "${num_list}")
  local kernel_conf_file='/etc/sysctl.d/k8s.conf'

  # 移除节点容器环境
  for ip in ${host_list}; do
    # 清理sysctl 内核参数环境
    ssh "${login_user}@${ip}" "[ -f ${kernel_conf_file} ] && rm -f ${kernel_conf_file}"
    echo -e "\e[32m节点${ip}清理内核参数环境成功!!!\e[0m"
  done
}

# 基于主机名方式移除内核参数环境
use_hostname_method_clean_sysconf_env(){
  # 接收参数
  local node_name="$1"
  local kernel_conf_file='/etc/sysctl.d/k8s.conf'

  # 清理sysctl 内核参数环境
  ssh "${login_user}@${node_name}" "[ -f ${kernel_conf_file} ] && rm -f ${kernel_conf_file}"
  echo -e "\e[32m节点${ip}清理内核参数环境成功!!!\e[0m"
}

# 移除内核参数环境
k8s_cluster_node_sysconf_clean(){
  # 获取节点信息
  k8s_cluster_node_print_from_hosts "${host_file}"

  # 定制要缩容的基本信息
  read -p "请输入您要删除内核环境所在节点的方式(iptail|hostname|all): " node_delete_type
  if [ "${node_delete_type}" == "iptail" ]; then
    read -p "请输入您要删除节点的列表,只需要ip最后一位(示例: {12..20}): " num_list
    # 基于IP地址的节点缩容
    use_ip_method_clean_sysconf_env "${num_list}"
  elif [ "${node_delete_type}" == "hostname" ]; then
    read -p "请输入您要删除节点的主机名(示例: kubernetes-node): " delete_node_hostname
    use_hostname_method_clean_sysconf_env "${delete_node_hostname}"
  elif [ "${node_delete_type}" == "all" ]; then
    local all_node=$(awk -F'[.| ]' '/master|node/{print $4}' "${host_file}")
    use_ip_method_clean_sysconf_env "${all_node}"
  else
    echo -e "\e[31m请输入有效的节点移除方式\e[0m"
  fi
}

# 基于IP地址方式移除ssh环境
use_ip_method_clean_ssh(){
  # 接收参数
  local num_list="$*"
  local host_list=$(create_ip_list "${target_net}" "${num_list}")

  # 移除节点容器环境
  for ip in ${host_list}; do
    # 清理ssh环境
    sshkey_auth_exist_delete "${ip}"
    # 移除本地hosts文件的主机解析记录
    sed -i "/${ip}/d" "${host_file}"
    echo -e "\e[32m节点${ip}清理ssh环境成功!!!\e[0m"
  done
}

# 基于主机名方式移除ssh环境
use_hostname_method_clean_ssh(){
  # 接收参数
  local node_name="$1"

  # 清理ssh环境
  sshkey_auth_exist_delete "${node_name}"
  # 移除本地hosts文件的主机解析记录
  sed -i "/${node_name}/d" "${host_file}"
  echo -e "\e[32m节点${ip}清理内核参数环境成功!!!\e[0m"
}

# 移除ssh认证环境
k8s_cluster_node_ssh_clean(){
  # 获取节点信息
  k8s_cluster_node_print_from_hosts "${host_file}"

  # 定制要缩容的基本信息
  read -p "请输入您要删除ssh环境所在节点的方式(iptail|hostname|k8s|all): " node_delete_type
  if [ "${node_delete_type}" == "iptail" ]; then
    read -p "请输入您要删除节点的列表,只需要ip最后一位(示例: {12..20}): " num_list
    # 基于IP地址的节点缩容
    use_ip_method_clean_ssh "${num_list}"
  elif [ "${node_delete_type}" == "hostname" ]; then
    read -p "请输入您要删除节点的主机名(示例: kubernetes-node): " delete_node_hostname
    use_hostname_method_clean_ssh "${delete_node_hostname}"
  elif [ "${node_delete_type}" == "k8s" ]; then
    echo -e "\e[33m清理所有k8s集群节点的ssh认证记录信息...\e[0m"
    local all_k8s_node=$(awk -F'[.| ]' '/master|node/{print $4}' "${host_file}")
    use_ip_method_clean_ssh "${all_k8s_node}"
  elif [ "${node_delete_type}" == "all" ]; then
    echo -e "\e[33m清理所有k8s集群节点的ssh认证记录信息...\e[0m"
    local all_node=$(awk -F'[.| ]' '/kube/{print $4}' "${host_file}")
    use_ip_method_clean_ssh "${all_node}"
  else
    echo -e "\e[31m请输入有效的节点移除方式\e[0m"
  fi
}

# 移除harbor环境函数
k8s_cluster_node_harbor_clean_logic(){
  # 接收参数
  local remote_addr="$1"
  local service_name="harbor.service"
  local harbor_service_path="/lib/systemd/system/${service_name}"
  local harbor_server_path="${server_dir}/harbor"

  # 获取远程主机harbor服务状态
  local remote_harbor_status=$(remote_node_service_status_check "${remote_addr}" "${service_name}")
  if [ "${remote_harbor_status}" == "active" ]; then
    # 清理节点harbor环境
    ssh "${login_user}@${remote_addr}" "systemctl disable --now ${service_name}; \
                                        systemctl stop ${service_name}; \
                                        rm -rf ${harbor_service_path} ${harbor_server_path}"
    echo -e "\e[32m节点${remote_addr}移除harbor环境成功!!!\e[0m"
  else
    echo -e "\e[33m节点${remote_addr}没有harbor环境!!!\e[0m"
  fi
   
}

# 
# compose在线移除
compose_remove_online(){
  # 接收参数
  local remote_addr="$1"

  # 判断远程harbor是什么系统类型
  local os_type=$(get_remote_os_type "remote" "${remote_addr}")
  local cmd_type=$(get_remote_cmd_type "remote" "${remote_addr}")
  local compose_bin="${compose_bin_dir}/${compose_cmd_name}"

  # 定制软件源更新命令
  if [ "${os_type}" == "Ubuntu" ]; then
    remote_cmd="${cmd_type} --purge remove ${compose_cmd_name} -y"
  else
    remote_cmd="${cmd_type} remove ${compose_cmd_name} -y"
  fi
  ssh "${login_user}@${remote_addr}" "[ -f "${compose_bin}" ] && ${remote_cmd}"
  # 为了确保删除环境，再次校验
  local compose_status=$(compose_status_check)
  [ "${compose_status}" == "is_exist" ] && ssh "${login_user}@${remote_addr}" " \
                                                rm -f ${compose_bin}"
}

# compose离线部署
compose_remove_offline(){
  # 定制参数
  local remote_addr="$1"
  local compose_bin="${compose_bin_dir}/${compose_cmd_name}"

  # 解压本地文件
  if [ -f "${compose_bin}"  ];then
    ssh "${login_user}@${remote_addr}" "rm -f ${compose_bin}"
  fi
}

# 移除docker-compose环境函数
k8s_cluster_node_harbor_compose_clean(){
  # 接收参数
  local remote_addr="$1"
  local service_name="compose.service"
  # 获取远程主机compose状态
  local compose_status=$(compose_status_check)
  if [ "${compose_status}" == "is_exist" ]; then
    # 确认移除compose的方式
    if [ "${default_deploy_type}" == "online" ]; then
      # 获取远程主机操作命令类型
      local cmd_type=$(get_remote_cmd_type "remote" "${remote_addr}")    
      # 在线方式移除compose环境
      compose_remove_online "${remote_addr}"
    else
      # 离线方式移除compose环境
      compose_remove_offline "${remote_addr}"
    fi
    echo -e "\e[32m节点${remote_addr}移除compose环境成功!!!\e[0m"
  else
    echo -e "\e[33m节点${remote_addr}没有compose环境!!!\e[0m"
  fi
}
# 移除harbor环境
k8s_cluster_node_harbor_clean(){
  
  # 备份harbor镜像文件
  harbor_repo_image_file_backup

  # 判断harbor集群类型
  if [ "${default_harbor_cluster_type}" == "alone" ]; then
    # 移除harbor环境
    k8s_cluster_node_harbor_clean_logic "${harbor_addr}"
    # 移除docker-compose环境
    k8s_cluster_node_harbor_compose_clean "${harbor_addr}"
    # 移除docker环境
    container_service_docker_clean "${harbor_addr}"
    # 重启harbor主机环境
    remote_host_is_reboot "yes" "${harbor_addr}"
  else
    echo "按照多节点集群方式移除harbor环境"
  fi
}

# 移除ssh记录信息
k8s_cluster_node_ssh_clean(){
  # 接收参数
  local remote_addr="$1"

  # 删除指定节点的ssh认证秘钥
  sshkey_auth_exist_delete "${remote_addr}"   
  
  # 从本地主机的hosts文件里面移除
  sed -i "/${remote_addr}/d" "${host_file}"
}

# 一键k8s集群环境重置
k8s_cluster_one_key_reset(){
  # 接收参数
  local host_reboot_status="$1"

  # 获取当前节点的状态信息
  local temp_node_list_file="/tmp/k8s_node.txt"
  k8s_cluster_nodes_get "${temp_node_list_file}"

  # 工作节点重置
  k8s_cluster_nodes_clean_auto "${host_reboot_status}" "reset"
  
  # 控制节点重置
  k8s_cluster_reset_node_logic "master" "${master1}"  

  # 重启主机
  if [ "${host_reboot_status}" == "yes" ]; then
    local all_k8s_node=$(awk '/master|node/{print $1}' "${host_file}")
    for remote_addr in ${all_k8s_node}; do
      remote_host_is_reboot "${host_reboot_status}" "${remote_addr}" 
    done
  fi
}


# 一键k8s集群环境清理
k8s_cluster_one_key_clean(){
  # 接收参数
  local harbor_clean_status="$1"
  local host_reboot_status="yes"

  # 获取当前节点的状态信息
  local temp_node_list_file="/tmp/k8s_node.txt"
  k8s_cluster_nodes_get "${temp_node_list_file}"

  # 工作节点清理
  k8s_cluster_nodes_clean_auto "${host_reboot_status}" "clean"
  
  # 控制节点清理
  k8s_cluster_master_clean_auto "${host_reboot_status}" "clean"
 
  # 清理harbor环境
  if [ "${harbor_clean_status}" == "yes" ]; then
    k8s_cluster_node_harbor_clean
  fi

  # 清理ssh环境
  local remote_list=$(grep 'kube' "${host_file}")
  for addr in ${remote_list}; do
    k8s_cluster_node_ssh_clean "${addr}"
  done  
}
