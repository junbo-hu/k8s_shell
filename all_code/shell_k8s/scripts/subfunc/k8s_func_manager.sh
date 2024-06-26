#!/bin/bash
# *************************************
# 功能: kubernetes 集群功能管理函数库
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 版本: v0.1
# 日期: 2024-01-28
# *************************************

# 定制主机重启动作
remote_host_is_reboot(){
  # 接收参数
  local host_reboot_status="$1"
  local reboot_host_addr="$2"

  # 重启逻辑判断
  if [ "${host_reboot_status}" == "yes" ];then
    ssh "${login_user}@${reboot_host_addr}" "reboot"
  fi
}

# k8s集群移除节点函数
k8s_cluster_reset_node_logic(){
  # 接收参数
  local host_role="$1"
  local host_list="$2"

  # 对所有目标主机机芯环境清理动作
  for ip in ${host_list}; do
    # 清理集群环境
    ssh "${login_user}@${ip}" "echo y | kubeadm reset ${cri_options}; \
                               systemctl disable kubelet; \
                               systemctl restart kubelet; \
                               rm -rf /etc/cni/net.d"
    # 对master主机和node主机的区别对待
    if [ "${host_role}" == "master" ]; then
       ssh "${login_user}@${ip}" "sed -i '/(kube/d' ~/.bashrc"
    fi
    echo -e "\e[32m节点${ip}进行kubernetes集群重置操作成功!!!\e[0m"
  done
}

# k8s集群节点清理函数
k8s_cluster_clean_node(){
  # 接收参数
  local host_role="$1"
  local host_list="$2"
  local host_reboot_status="$3"
  
  # 对所有目标主机环境进行重置动作
  k8s_cluster_reset_node_logic "${host_role}" "${host_list}"
  
  # 对所有目标主机环境进行重启动作
  for ip in ${host_list}; do
    # 通过重启主机的方式，清理网络相关的信息
    remote_host_is_reboot "${host_reboot_status}" "${ip}"
  done
}

# 检测主机存活状态函数
node_status_check(){
  # 接收参数
  local node_name="$1"

  # 检测主机状态
  local node_status=$(ssh "${login_user}@${master1}" "kubectl get nodes" \
                              | grep ${node_name} >/dev/null && echo "exist" || echo "noexist")
  echo "${node_status}"
}

# 从集群移除节点函数
node_delete_from_cluster(){
  # 接收参数
  local node_name="$1"
  local delete_node_verify="$2"

  # 定制节点清理的选项参数
  local drain_opt='--delete-emptydir-data --force --ignore-daemonsets=true'
  local taint_opt='diskfull=true:NoSchedule' 
  if [ "${delete_node_verify}" == "yes" ];then
    local delete_node_cmd=";kubectl delete node ${node_name}"
  else
    local delete_node_cmd=""
  fi

  # 节点清理
  ssh "${login_user}@${master1}" "kubectl cordon ${node_name}; \
                                  kubectl drain ${node_name} ${drain_opt}; \
                                  kubectl taint nodes ${node_name} ${taint_opt} \
                                  ${delete_node_cmd}"
}

# 基于hostname的节点删除逻辑函数
scale_in_node_logic_use_name(){
  # 接收参数
  local node_name="$1"
  
  # 检测节点状态，避免重复移除报错
  local node_status=$(node_status_check "${node_name}")
  
  if [ "${node_status}" == "exist" ];then
    # 如果待删除节点存在，清理节点+移除节点
    node_delete_from_cluster "${node_name}" "yes"

    # 验证节点移除效果
    local node_delete_status=$(node_status_check "${node_name}")
    if [ "${node_delete_status}" == "noexist" ];then
      echo -e "\e[32m当前kubernets集群移除${node_name}节点操作成功!!!\e[0m"
      # 节点清理完毕后，配置收尾操作
      # k8s_cluster_clean_node "node" "${host_list}" "${host_reboot_status}"
    else
      echo -e "\e[31m当前kubernets集群移除${node_name}节点操作失败!!!\e[0m"
    fi
  else
    echo -e "\e[32m当前kubernets集群没有${node_name}节点，无需执行移除操作!!!\e[0m"
  fi
}

# 进行节点移除后的配置清理
scale_in_node_after_reset_use_ip(){
  # 接收参数
  local host_reboot_status=$(echo $* | awk '{print $NF}')
  local num_list=$(echo $* | awk '{$NF=null;print $0}')

  # 获取待删除的节点IP地址
  local host_list=$(create_ip_list "${target_net}" "${num_list}")
  
  # 对指定的主机列表进行缩容操作
  for ip in ${host_list}; do
    # 获取待删除节点的主机名
    local node_name=$(grep ${ip} ${host_file} | awk '{print $NF}')
    # 验证节点移除效果
    local node_delete_status=$(node_status_check "${node_name}")
    if [ "${node_delete_status}" == "noexist" ];then
      # 自动识别主机角色
      local node_role=$(get_remote_node_role "${node_name}")
      # 节点清理完毕后，配置收尾操作
      k8s_cluster_clean_node "${node_role}" "${host_list}" "${host_reboot_status}"
    else
      echo -e "\e[31m当前kubernets集群${node_name}节点存在无法进行清理配置操作!!!\e[0m"
    fi
  done
}

# 基于IP地址的节点删除逻辑函数
scale_in_node_logic_use_ip(){
  # 接收参数
  local num_list="$*"

  # 获取待删除的节点IP地址
  local host_list=$(create_ip_list "${target_net}" "${num_list}")
  
  # 对指定的主机列表进行缩容操作
  for ip in ${host_list}; do
    # 获取待删除节点的主机名
    local node_name=$(grep ${ip} ${host_file} | awk '{print $NF}')
    # 基于主机名来删除节点
    scale_in_node_logic_use_name "${node_name}"
  done
}

# 基于IP地址的节点重置逻辑函数
scale_in_node_logic_use_ip_reset(){
  # 接收参数
  local host_reboot_status=$(echo $* | awk '{print $NF}')
  local num_list=$(echo $* | awk '{$NF=null;print $0}')

  # 从k8s集群中移除主机条目
  scale_in_node_logic_use_ip "${num_list}"
  
  # 清理节点的集群配置文件
  scale_in_node_after_reset_use_ip "${num_list}" "${host_reboot_status}"
}

# 基于IP地址的节点环境清理逻辑函数
scale_in_node_logic_use_ip_remove(){
  # 接收参数
  local host_reboot_status=$(echo $* | awk '{print $NF}')
  local num_list=$(echo $* | awk '{$NF=null;print $0}')

  # 重置集群节点 - 不要重启主机
  scale_in_node_logic_use_ip_reset "${num_list}" "no"

  # 清理节点的集群配置文件
  local host_list=$(create_ip_list "${target_net}" "${num_list}")

  # 对指定的主机列表进行软件移除操作
  for ip in ${host_list}; do
    # 进行远程主机的软件清理动作
    k8s_cluster_nodes_softs_remove "${ip}"
    # 进行远程主机的软件源清理动作
    k8s_cluster_nodes_repo_remove "${ip}"
    # 远程主机重启操作
    remote_host_is_reboot "${host_reboot_status}" "${ip}"
  done
}

# 基于IP地址的节点环境还原逻辑函数
scale_in_node_logic_use_ip_clean(){
  # 接收参数
  local host_reboot_status=$(echo $* | awk '{print $NF}')
  local num_list=$(echo $* | awk '{$NF=null;print $0}')

  # 重置集群节点 - 不要重启主机
  scale_in_node_logic_use_ip_remove "${num_list}" "no"

  # 清理节点的集群配置文件
  local host_list=$(create_ip_list "${target_net}" "${num_list}")

  # 对指定的主机列表进行软件移除操作
  for ip in ${host_list}; do
    # 获取ip地址的最后一位
    local num_list=$(echo "${ip}" | awk -F'.' '{print $NF}')
    # 进程远程主机容器环境清理
    use_ip_method_clean_node_container "${num_list}"
    # 进行远程主机内核环境清理
    use_ip_method_clean_sysconf_env "${num_list}"
    # 注意：可以忽略， 进程远程主机的ssh信息清理
    # 远程主机重启操作
    remote_host_is_reboot "${host_reboot_status}" "${ip}"
  done
  # 远程ssh环境清理
  # echo "部署服务器的ssh记录清理"    
}

# 基于IP方式的多场景节点缩容函数
use_ip_method_scale_in_node(){
  # 接受参数
  local scale_type=$(echo $* | awk '{print $NF}')
  local host_reboot_status=$(echo $* | awk '{print $(NF-1)}')
  local num_list=$(echo $* | awk '{$NF=null;$(NF-1)=null;print $0}')

  # 定制多场景节点缩容判断
  case "${scale_type}" in
    "delete")
      # 基于ip的节点删除
      scale_in_node_logic_use_ip "${num_list}";;
    "reset")
      # 基于ip的节点重置
      scale_in_node_logic_use_ip_reset "${num_list}" "${host_reboot_status}";;
    "remove")
      # 基于ip的节点移除
      scale_in_node_logic_use_ip_remove "${num_list}" "${host_reboot_status}";;
    "clean")
      # 基于ip的节点清理
      scale_in_node_logic_use_ip_clean "${num_list}" "${host_reboot_status}";;
    *)
      echo -e "\e[31m请输入有效的节点缩容级别!!!\e[0m"
      echo -e "\e[31m选项如下: delete|reset|remove|clean\e[0m";;
  esac
}

# 进行节点移除后的配置清理
scale_in_node_after_reset_use_name(){
  # 接收参数
  local node_name="$1"
  local host_reboot_status="$2"

  # 验证节点移除效果
  local node_delete_status=$(node_status_check "${node_name}")
  if [ "${node_delete_status}" == "noexist" ];then
    # 自动识别主机角色
      local node_role=$(get_remote_node_role "${node_name}")
    # 节点清理完毕后，配置收尾操作
    k8s_cluster_clean_node "${node_role}" "${node_name}" "${host_reboot_status}"
  else
    echo -e "\e[31m当前kubernets集群${node_name}节点存在无法进行清理配置操作!!!\e[0m"
  fi
}

# 基于主机名的节点重置逻辑函数
scale_in_node_logic_use_name_reset(){
  # 接收参数
  local node_name="$1"
  local host_reboot_status="$2"

  # 清理节点的记录
  scale_in_node_logic_use_name "${node_name}"

  # 清理节点的集群配置文件
  scale_in_node_after_reset_use_name "${node_name}" "${host_reboot_status}"
}

# 基于主机名的节点环境清理逻辑函数
scale_in_node_logic_use_name_remove(){
  # 接收参数
  local node_name="$1"
  local host_reboot_status="$2"

  # 重置集群节点 - 不要重启主机
  scale_in_node_logic_use_name_reset "${node_name}" "no"
  
  # 进行远程主机的软件清理动作
  k8s_cluster_nodes_softs_remove "${node_name}"
  # 进行远程主机的软件源清理动作
  k8s_cluster_nodes_repo_remove "${node_name}"
  # 远程主机重启操作
  remote_host_is_reboot "${host_reboot_status}" "${node_name}"
}

# 基于主机名的节点环境还原逻辑函数
scale_in_node_logic_use_name_clean(){
  # 接收参数
  local node_name="$1"
  local host_reboot_status="$2"

  # 重置集群节点 - 不要重启主机
  scale_in_node_logic_use_name_remove "${node_name}" "no"

  # 进程远程主机容器环境清理
  use_hostname_method_clean_node_container "${node_name}"
  # 进行远程主机内核环境清理
  use_hostname_method_clean_sysconf_env "${node_name}"
  # 注意：可以忽略，进程远程主机的ssh信息清理
  # 远程主机重启操作
  remote_host_is_reboot "${host_reboot_status}" "${node_name}"
  # 远程ssh环境清理
  # echo "部署服务器的ssh记录清理"
}

# 基于主机名方式的多场景节点缩容函数
use_hostname_method_scale_in_node(){
  # 接受参数
  local node_name="$1"
  local host_reboot_status="$2"
  local scale_type="$3"

  # 定制多场景节点缩容判断
  case "${scale_type}" in
    "delete")
      # 基于hostname的节点删除
      scale_in_node_logic_use_name "${node_name}";;
    "reset")
      # 基于hostname的节点重置
      scale_in_node_logic_use_name_reset "${node_name}" "${host_reboot_status}";;
    "remove")
      # 基于hostname的节点移除
      scale_in_node_logic_use_name_remove "${node_name}" "${host_reboot_status}";;
    "clean")
      # 基于hostname的节点清理
      scale_in_node_logic_use_name_clean "${node_name}" "${host_reboot_status}";;
    *)
      echo -e "\e[31m请输入有效的节点缩容级别!!!\e[0m"
      echo -e "\e[31m选项如下: delete|reset|remove|clean\e[0m";;
  esac
}
# k8s集群节点缩容函数
scale_in_node(){
  # 接收参数
  # scale_type 支持 delete|reset|remove|clean 四种级别的节点缩容场景
  local scale_type="$1"

  # 定制临时数据文件
  local temp_node_list_file="/tmp/k8s_node.txt"
  # 获取当前集群的工作节点列表
  k8s_cluster_nodes_list "${temp_node_list_file}"

  # 定制要缩容的基本信息
  read -p "请输入您要删除节点的方式(iptail|hostname|all): " node_delete_type
  read -p "删除节点后，是否需要立刻重启节点主机(yes-默认|no): " node_is_reboot
  [ -z "${node_is_reboot}" ] && local node_is_reboot="yes"
  if [ "${node_delete_type}" == "iptail" ]; then
    read -p "请输入您要删除节点的列表,只需要ip最后一位(示例: {12..20}): " num_list
    # 基于IP地址的节点缩容
    use_ip_method_scale_in_node "${num_list}" "${node_is_reboot}" "${scale_type}"
    # scale_in_node_logic_use_ip "${num_list}"
  elif [ "${node_delete_type}" == "hostname" ]; then
    read -p "请输入您要删除节点的主机名(示例: kubernetes-node): " delete_node_hostname
    use_hostname_method_scale_in_node "${delete_node_hostname}" "${node_is_reboot}" "${scale_type}"
  elif [ "${node_delete_type}" == "all" ]; then
    local all_node=$(awk -F'.' '/node/{print $NF}' "${temp_node_list_file}")
    use_ip_method_scale_in_node "${all_node}" "${node_is_reboot}" "${scale_type}"
  else
    echo -e "\e[31m请输入有效的节点移除方式\e[0m"
  fi
}

# 定制一键主机基础环境
one_key_new_node_base_env(){
  # 接收参数
  local ip_addr="$1"
  # 定制一键主机基础环境局
  sshkey_auth_func "${ip_addr}"
  scp_file ${ip_addr} "${host_file}" "${host_target_dir}"
  set_hostname ${ip_addr}
  repo_update "${ip_addr}"
}

# 定制一键集群基础环境
one_key_new_node_cluster_env(){
  # 接收参数
  local ip_addr="$1"
  # 定制k8s内核参数及容器环境部署
  k8s_kernel_config "${ip_addr}"
  docker_deploy_install "${default_deploy_type}" "${ip_addr}"
  cri_deploy_offline "${ip_addr}"
}

# 定制一键集群软件环境
one_key_k8s_softs(){
  # 接收参数
  local ip_addr="$1"
  # 定制软件源以及软件安装
  create_repo "${ip_addr}"
  k8s_install "${default_deploy_type}" "${ip_addr}"
}

# 定制一键节点加入集群环境
one_key_add_node(){
  # 接收参数
  local ip_addr="$1"
  # master节点生成 节点加入集群命令
  local add_sub_cmd=$(ssh "${login_user}@${master1}" "kubeadm token create --print-join-command --ttl 1m")
  local add_node_cmd="${add_sub_cmd} ${cri_options}"
  # bug修复: 获取master节点类型
  local master_os_type=$(ssh ${login_user}@${master1} "grep -i ubuntu /etc/issue" >> /dev/null \
                                                       && echo "Ubuntu" || echo "CentOS")
  for node in ${ip_addr};
  do
    # bug修复: 获取node节点类型
    local node_os_type=$(ssh ${login_user}@${node} "grep -i ubuntu /etc/issue" >> /dev/null \
                                                       && echo "Ubuntu" || echo "CentOS")
    # bug修复: 解决Centos主机因为resolv.conf文件，导致kubelet无法启动
    if [[ "${master_os_type}" == "Ubuntu" && "${node_os_type}" == "CentOS" ]]; then
       scp "${scripts_dir}/${ext_scripts_dir}/${k8s_node_centos_tail_scripts}" "${login_user}@${node}:/etc/profile.d/"
       # 多做一次文件检测
       local resolv_file='/run/systemd/resolve/resolv.conf'
       ssh "${login_user}@${node}" "[ -f ${resolv_file} ] || /bin/bash /etc/profile.d/${k8s_node_centos_tail_scripts}"
       # bug修复: 设置node节点kubelet服务开机自启动
       ssh "${login_user}@${node}" "systemctl enable kubelet"
    fi
    # 工作节点增加的逻辑
    ssh ${login_user}@$node "${add_node_cmd}"
    
    # master节点验证加入效果
    local node_name=$(grep ${ip_addr} ${host_file} | awk '{print $NF}')
    local check_node_status=$(node_status_check "${node_name}")
    if [ "${check_node_status}" == "exist" ];then
      echo -e "\e[32m当前kubernets集群扩容${ip_addr}节点操作成功!!!\e[0m"
    else
      echo -e "\e[31m当前kubernets集群扩容${ip_addr}节点操作失败!!!\e[0m"
    fi
  done

  # node节点执行加入集群命令
  # ssh "${login_user}@${ip_addr}" "${add_node_cmd}"
}

# k8s集群节点缩容函数
scale_out_node(){
  # 定制临时数据文件
  local temp_node_list_file="/tmp/k8s_node.txt"
  # 获取当前集群的工作节点列表
  k8s_cluster_nodes_list "${temp_node_list_file}"
  # 定制要缩容的基本信息
  read -p "请输入您要扩容节点的类型(master|node): " host_role
  if [[ "${host_role}" == "master" || "${host_role}" == "node" ]]; then
    read -p "请输入您要批量扩容节点的主机列表,只需要ip最后一位(示例: {12..20}): " num_list
    local ip_list=$(create_ip_list "${target_net}" "${num_list}")
    # 对指定的主机列表进行扩容操作
    for ip in ${ip_list}; do
      local node_name=$(grep ${ip} ${host_file} | awk '{print $NF}')
      # 如果指定节点已经存在，避免重复添加报错
      local node_status=$(node_status_check "${node_name}")
      if [ "${node_status}" == "exist" ];then
        echo -e "\e[32m当前kubernets集群已存在${node_name}节点，无需执行扩容操作!!!\e[0m"
      else
        # 大量需要定制的一键功能函数
        one_key_new_node_base_env "${ip}"
        one_key_new_node_cluster_env "${ip}"
        one_key_k8s_softs "${ip}"
        one_key_add_node "${ip}"
      fi
    done
  else
    echo -e "\e[31m请输入有效的节点类型\e[0m"
  fi
}

# k8s工作节点更新函数
k8s_node_update(){
  # 参数定制
  local version="$1"
  local update_ver="$2"
  local ip_list="$3"

  # 定制要更新的基本信息
  local ver_num=$(echo "${update_ver}" | awk -F'.' '{print $2}')

  # 对工作节点主机列表范围内的主机进行更新操作
  for ip in ${ip_list}; do
    # 获取工作节点软件版本信息
    local node_name=$(grep ${ip} ${host_file} | awk '{print $NF}')
    local node_ver=$(ssh "${login_user}@${master1}" "kubectl get nodes" \
                             | grep ${node_name} | awk '{print $NF}')
    # 获取待更新版本号和当前版本号的差值
    local node_ver_num=$(echo "${node_ver}" | awk -F'.' '{print $2}')
    local diff_ver=$(( $ver_num - $node_ver_num ))
    local diff_ver_num=$(echo_abs "${diff_ver}")
    
    # 判断集群工作节点是否需要更新
    if [ "${update_ver}" == "${node_ver}" ];then
      echo -e "\e[33m${node_name}节点的k8s软件版本已经更新完毕，无需重复更新\e[0m"
    else
      # k8s集群版本更新的三种策略功能判断
      k8s_soft_update_policy "${version}" "${ver_num}" "${diff_ver}" "${diff_ver_num}" "${node_ver}" "${update_ver}" "${ip}"
      [ "${rollout_status}" == "stop_update" ] && return 127

      node_delete_from_cluster "${node_name}" "no"
      # 工作节点安装指定版本软件
      full_cmd="${sub_cmd}; ${softs_update_cmd}  ${cmd_type} install -y kubeadm${soft_tail} kubectl${soft_tail} kubelet${soft_tail}"
      ssh "${login_user}@${ip}" ${full_cmd}
      # 执行指定节点更新软件
      ssh "${login_user}@${ip}" "kubeadm upgrade node; systemctl daemon-reload; \
                                 systemctl restart docker kubelet"
      # 取消待更新节点的冻结和驱离动作
      ssh "${login_user}@${master1}" "kubectl taint node ${node_name} diskfull-; \
                                      kubectl uncordon ${node_name}"
      echo -e "\e[32m${node_name}节点的k8s软件版本更新完毕!!!\e[0m"
    fi
  done
}
# 更新软件的策略
k8s_soft_update_policy(){
  # 接收参数
  local version="$1"
  local ver_num="$2"
  local diff_ver="$3"
  local diff_ver_num="$4"
  local node_ver="$5"
  local update_ver="$6"
  local remote_host="$7"

  # 禁止k8s跨版本实现更新
  if [ "${diff_ver_num}" -gt 1 ] ; then
    echo -e "\e[31mk8s集群禁止跨多版本更新软件，请输入有效的待更新软件版本\e[0m"
  else
    # 待更新节点安装指定软件
    local os_type=$(ssh "${login_user}@${remote_host}" "grep -i ubuntu /etc/issue" >/dev/null && echo "Ubuntu" || echo "CentOS")
    k8s_softs_tail "${os_type}" "${ver_num}" "${version}"
    # bug修复: 软件升级和软件回退
    local node_sub_ver_num=$(echo "${node_ver}" | awk -F'.' '{print $NF}')
    local update_sub_ver_num=$(echo "${update_ver}" | awk -F'.' '{print $NF}')
    local diff_sub_ver=$(( $update_sub_ver_num - $node_sub_ver_num ))
    # 版本更新的大版本的判断条件
    if [ "${diff_ver}" -eq 1 ]; then
      # 场景1：大版本更新
      softs_update_cmd=""
    elif [ "${diff_ver}" -lt 0 ]; then
      # 场景2: 大版本回退
      echo -e "\e[31mK8s集群可能会因为组件版本兼容性问题，导致无法更新\e[0m"
      echo -e "\e[31m所以暂不提供集群大版本回退功能\e[0m"
      rollout_status="stop_update"
    else
      # 场景3: 小版本更新
      if [ "${diff_sub_ver}" -ge 0 ]; then
        softs_update_cmd=""
      else
        # 小版本回退
        softs_update_cmd="${cmd_type} remove kubeadm kubectl kubelet -y;"
      fi
    fi
   fi
}

# 多主分布式场景下，控制节点更新
k8s_multi_master_update(){
  # 参数定制
  local version="$1"
  local update_ver="$2"
  local etcd_update_status="$3"
  local ip_list="$4"

  echo -e "\e[33m对多主分布式场景下的，k8s集群控制节点开始进行更新...\e[0m"
  # for循环 + k8s_single_master_update
  for i in ${ip_list}; do
    echo -e "\e[33mk8s集群控制节点 ${i} 开始进行版本更新...\e[0m"
  done
}
# 单主分布式场景下，控制节点更新
k8s_single_master_update(){
  # 参数定制
  local version="$1"
  local update_ver="$2"
  local etcd_update_status="$3"
  local ip_list="$4"

  echo -e "\e[33m对单主分布式场景下的，k8s集群控制节点开始进行更新...\e[0m"
  # 由于多主分布式master节点的更新动作，可能有不太一样的东西，这里，暂时使用 master1 而不用 ip_list
  
  # 获取控制节点软件版本信息
  local node_name=$(grep ${master1} ${host_file} | awk '{print $NF}')
  local node_ver=$(ssh "${login_user}@${master1}" "kubectl get nodes" \
                             | grep ${node_name} | awk '{print $NF}')
  # 获取待更新版本号和当前版本号的差值
  local ver_num=$(echo "${update_ver}" | awk -F'.' '{print $2}')
  local node_ver_num=$(echo "${node_ver}" | awk -F'.' '{print $2}')
  local diff_ver=$(( $ver_num - $node_ver_num ))
  local diff_ver_num=$(echo_abs "${diff_ver}")

  # 判断集群控制节点是否需要更新
  if [ "${update_ver}" == "${node_ver}" ];then
    echo -e "\e[33m${node_name}节点的k8s软件版本已经更新完毕，无需重复更新\e[0m"
  else
    # k8s集群版本更新的三种策略功能判断
    k8s_soft_update_policy "${version}" "${ver_num}" "${diff_ver}" "${diff_ver_num}" "${node_ver}" "${update_ver}" "${master1}"
    [ "${rollout_status}" == "stop_update" ] && return 127
    
    # 控制节点安装k8s新版本软件
    full_cmd="${sub_cmd}; ${softs_update_cmd} ${cmd_type} install -y kubeadm${soft_tail} kubectl${soft_tail} kubelet${soft_tail}"
    ssh "${login_user}@${master1}" ${full_cmd}
    # 避免小版本降级，由于kubelet服务异常而导致失败，需要重启服务
    ssh "${login_user}@${master1}" "systemctl restart kubelet; systemctl enable kubelet"

    # k8s集群更新时候的一些参数选项: ETCD是否更新、镜像文件是否提前获取
    # 获取镜像
    local k8s_version="${version}"
    get_images "${default_repo_type}" "${master1}" "yes" "yes"
    
    # 如果涉及到ETCD同步更新，那么提前做ETCD的数据备份
    k8s_data_save 
  
    # 执行指定节点更新软件
    ssh "${login_user}@${master1}" "kubeadm upgrade apply -y ${update_ver} \
                                   --etcd-upgrade=${etcd_update_status} \
                                   --ignore-preflight-errors=all; \
                                   systemctl daemon-reload; \
                                   systemctl restart docker kubelet"
    # 检测控制节点软件版本更新效果
    sleep 5
    local node_ver=$(ssh "${login_user}@${master1}" "kubectl get nodes" \
                           | grep ${node_name} | awk '{print $NF}')
    if [ "${update_ver}" == "${node_ver}" ];then
      echo -e "\e[32m${node_name}节点的k8s软件版本更新完毕!!!\e[0m"
    fi
  fi
}
# k8s控制节点更新函数
k8s_master_update(){
  # 函数使用帮助
  # k8s_master_update "${version}" "${update_ver}" "${etcd_update_status}" "${ip_list}"
  # 参数定制
  local version="$1"
  local update_ver="$2"
  local etcd_update_status="$3"
  local ip_list="$4"

  # 定制要更新的基本信息
  local ver_num=$(echo "${update_ver}" | awk -F'.' '{print $2}')
  # 根据待更新的节点数量，来判断集群是否为高可用集群
  local ip_arry=("${ip_list}")
  local ip_list_num=${#ip_arry[*]}
  if [ "${ip_list_num}" -gt "1" ]; then
    # 多主分布式场景下，控制节点更新
    k8s_multi_master_update "${version}" "${update_ver}" "${etcd_update_status}" "${ip_list}"
  else
    # 单主分布式场景下，控制节点更新
    k8s_single_master_update "${version}" "${update_ver}" "${etcd_update_status}" "${ip_list}"
  fi
}
# 获取证书的基本信息
k8s_cert_get_expir_date(){
  # 定制参数
  local tmp_file='/tmp/.cert.txt'
  # 获取当前的证书有效期限信息
  ssh "${login_user}@${master1}" "kubeadm certs check-expiration" > "${tmp_file}"
  z_expir_date=$(grep '^admin' "${tmp_file}" | awk '{print $2,$3,$4,$5,$6}')
  c_expir_date=$(grep '^ca' "${tmp_file}" | awk '{print $2,$3,$4,$5,$6}')
  echo -e "\n-------当前K8s集群的证书有效期信息-------"
  echo "组件证书有效期至: ${z_expir_date}"
  echo " CA 证书有效期至: ${c_expir_date}"
  echo -e "-----------------------------------------\n"
}
# 使用k8s集群默认的方式更新证书
k8s_cert_update_renew(){
  # 获取当前的证书有效期限信息
  k8s_cert_get_expir_date
  # 更新证书有效期
  ssh "${login_user}@${master1}" "kubeadm certs renew all"
  # 重启所有的组件服务
  ssh "${login_user}@${master1}" "kubectl delete pod -l component -n kube-system"
  # 确认证书更新效果
  k8s_cert_get_expir_date
  echo -e "\e[32m当前k8s集群节点的证书更新完毕!!!\e[0m"
}

# 使用重置kubeadm命令的方式更新证书
k8s_cert_update_kubeadm(){
  echo "使用重置kubeadm命令的方式更新证书"
}

# 使用openssl灵活定制k8s集群证书
k8s_cert_update_openssl(){
  echo "使用openssl灵活定制k8s集群证书"
}

# 不更新k8s集群证书
k8s_cert_update_none(){
  echo -e "\e[33m集群一键升级场景下，忽略k8s集群证书更新!!!\e[0m"
}

# 定制k8s集群的证书更新
k8s_cert_update(){
  # 接收参数
  local cert_update_type="$1"

  # 判断用户输入证书更新的方式
  case "${cert_update_type}" in
    "renew")
      k8s_cert_update_renew;;
    "kubeadm")
      k8s_cert_update_kubeadm;;
    "openssl")
      k8s_cert_update_openssl;;
    "none")
      k8s_cert_update_none;;
    *)
      Usage;;
  esac
}

# 定制k8s集群etcdctl命令的函数
k8s_etcdctl_define(){
  # 检测master1主机是否有etcdctl命令
  ssh "${login_user}@${master1}" "[ -f ${etcdctl_cmd_dir}/etcdctl ]" \
                                 && local cmd_status="is_exist" \
                                 || local cmd_status="is_none"
  # 如果没有，就拷贝一个
  if [ "${cmd_status}" == "is_none" ]; then
    # 从ETCD容器里面获取命令
    etcd_container_id=$(ssh "${login_user}@${master1}" "docker ps" | grep 'etcd -' | awk '{print $1}')
    ssh "${login_user}@${master1}" "docker cp ${etcd_container_id}:${etcdctl_cmd_dir}/etcdctl ${etcdctl_cmd_dir}/"
    local etcdctl_version=$(ssh "${login_user}@${master1}" "etcdctl version" | awk '/etcdctl/{print $NF}')
    if [ -n "${etcdctl_version}" ]; then
      etcdctl_status="is_exist"
    else
      etcdctl_status="is_none"
    fi
  else
    # 提示etcdctl命令已存在
    echo -e "\e[32mK8s集群控制节点Etcdctl命令已存在!!!\e[0m"
    etcdctl_status="is_exist"
  fi
}

# 定制k8s集群数据备份函数
k8s_data_save(){
  # 检测etcdctl命令环境是否正常
  k8s_etcdctl_define
  # 如果命令存在，则进行数据备份
  if [ "${etcdctl_status}" == "is_exist" ]; then
    # 保证存在数据备份目录
    ssh "${login_user}@${master1}" "[ ! -d ${etcd_db_backup_dir} ] && mkdir -p ${etcd_db_backup_dir}"
    local date_time=$(date "+%Y%m%d%H%M%S")
    local etcd_db_file="snapshot-etcd-${date_time}.db"
    # 将该命令文件传输到远程主机并执行
    ssh "${login_user}@${master1}" "export ETCDCTL_API=3; etcdctl \
                                    --endpoints=${etcd_endpoint} \
                                    --cacert=${etcd_pki_dir}/ca.crt \
                                    --cert=${etcd_pki_dir}/server.crt \
                                    --key=${etcd_pki_dir}/server.key \
                                    snapshot save ${etcd_db_backup_dir}/${etcd_db_file}"
    # 检测远程数据备份文件状态
    ssh "${login_user}@${master1}" "[ -f ${etcd_db_backup_dir}/snapshot-etcd-${date_time}.db ]" \
                                     && local db_file_status="is_exist" \
                                     || local db_file_status="is_none"
    if [ "${db_file_status}" == "is_exist" ]; then
      echo -e "\e[32mK8s集群Etcd数据备份完毕，文件名: ${etcd_db_file}\e[0m"
    else
      echo -e "\e[31mK8s集群Etcd数据备份失败\e[0m"
      return
    fi
  else
    echo -e "\e[31mK8s集群控制节点Etcdctl命令不存在!!!\e[0m"
    return
  fi
}

# 定制k8s集群数据还原函数
k8s_data_restore(){
  # 检测etcdctl命令环境是否正常
  k8s_etcdctl_define
  # 如果命令存在，则进行数据备份
  if [ "${etcdctl_status}" == "is_exist" ]; then
    # 保证存在数据备份目录
    local backup_dir_status=$(ssh "${login_user}@${master1}" \
                                  "[ -d ${etcd_db_backup_dir} ] && echo 'is_exist' || echo 'is_node'")
    if [ "${backup_dir_status}" == "is_exist" ]; then
      # 查看远程目录下的文件
      echo "--------远程主机etcd备份目录下的数据文件--------"
      for i in $(ssh "${login_user}@${master1}" "ls ${etcd_db_backup_dir}"); do
        echo "${i}"
      done
      echo "------------------------------------------------"
      # 确认要恢复的etcd数据文件
      read -t 10 -p "请输入要还原的etcd数据文件名: " etcd_db_file_name
      if [ -n "${etcd_db_file_name}" ]; then
        local restore_etcd_file_status=$(ssh "${login_user}@${master1}" \
                                  "[ -f ${etcd_db_backup_dir}/${etcd_db_file_name} ] \
                                  && echo 'is_exist' || echo 'is_node'")
        if [ "${restore_etcd_file_status}" == "is_node" ]; then
          echo -e "\e[31m您输入的Etcd数据文件不存在，请重新输入!!!\e[0m"
          return
        fi
      else
        echo -e "\e[31m您输入Etcd数据文件名为空，请再次输入!!!\e[0m"
        return
      fi
      # 停止远程主机的相关服务
      ssh "${login_user}@${master1}" "mv ${etcd_mainfest_dir} ${etcd_mainfest_dir}-bak"
      sleep 5
      # 对远程主机的etcd数据进行备份
      local date_time=$(date "+%Y%m%d%H%M%S")
      local etcd_data_backup="etcd-${date_time}"
      ssh "${login_user}@${master1}" "[ ! -d ${etcd_data_backup_dir} ] && mkdir -p ${etcd_data_backup_dir}"
      ssh "${login_user}@${master1}" "mv ${etcd_data_dir} ${etcd_data_backup_dir}/${etcd_data_backup}"
      sleep 7
      # etcd数据还原操作
      ssh "${login_user}@${master1}" "export ETCDCTL_API=3; etcdctl \
                                    --endpoints=${etcd_endpoint} \
                                    --cacert=${etcd_pki_dir}/ca.crt \
                                    --cert=${etcd_pki_dir}/server.crt \
                                    --key=${etcd_pki_dir}/server.key \
                                    snapshot restore ${etcd_db_backup_dir}/${etcd_db_file_name} \
                                    --data-dir=${etcd_data_dir}"
      # 恢复远程主机的相关服务
      ssh "${login_user}@${master1}" "mv ${etcd_mainfest_dir}-bak ${etcd_mainfest_dir}"
      sleep 5
      echo -e "\e[32mK8s集群Etcd数据还原操作执行完毕，请到控制节点确认效果!!!\e[0m"
    else
      echo -e "\e[31mK8s集群Etcd数据备份目录不存在!!!\e[0m"
      return
    fi
  else
    echo -e "\e[31mK8s集群控制节点Etcdctl命令不存在!!!\e[0m"
    return
  fi 
}

# 定制一键集群升级功能函数
k8s_onekey_update(){
  # 函数调用格式
  # k8s_onekey_update "${version}" "${update_ver}" "${etcd_update_status}"
  
  # 接收参数
  local version="$1"
  local update_ver="$2"
  local etcd_update_status="$3"

  # 获取集群控制节点范围
  # 根据当前集群类型，确定要更新的节点地址
  if [ "${cluster_type}" == "multi" ]; then
    #  通过for循环host文件方式获取
    master_list=""
    for i in $(grep 'master' "${host_file}" | awk '{print $1}');
    do
      # 通过拼接的方式，获取所有的master节点IP
      master_list="${master_list}$i "
    done
  else
    master_list="${master1}"
  fi
  # 获取集群工作节点范围
  node_list=""
  for i in $(grep 'node' "${host_file}" | awk '{print $1}');
  do
    node_list="${node_list}$i "
  done

  # 控制节点更新
  k8s_master_update "${version}" "${update_ver}" "${etcd_update_status}" "${master_list}"
  sleep 5
  # 工作节点更新
  k8s_node_update "${version}" "${update_ver}" "${node_list}"

  # 集群证书更新
  k8s_cert_update "none"
}
