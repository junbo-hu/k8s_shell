#!/bin/bash
# *************************************
# 功能: K8s集群初始化所依赖的功能函数
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 版本: v0.1
# 日期: 2023-07-31
# *************************************


# 定制CentOS 软件源函数
centos_repo(){
  # 定制centos环境软件源
  [ -f "/tmp/${centos_repo_file}" ] && rm -f "/tmp/${centos_repo_file}"
  cat > "/tmp/${centos_repo_file}" <<-eof
[kubernetes]
name=Kubernetes
baseurl=https://${k8s_sources_repo_addr}/kubernetes/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=0
eof
}

centos_repo_update(){
  for i in $(eval echo {28..$k8s_ver_num}); do
    cat >> "/tmp/${centos_repo_file}" <<-eof
[kubernetes-1.${i}]
name=Kubernetes-1.${i}
baseurl=https://mirrors.aliyun.com/kubernetes-new/core/stable/v1.${i}/rpm/
enabled=1
gpgcheck=0
eof
  done
}

# 定制Ubuntu 软件源函数
ubuntu_repo(){
  # 定制ubuntu环境软件源
  [ -f "/tmp/${ubuntu_repo_file}" ] && rm -f "/tmp/${ubuntu_repo_file}"
  cat >"/tmp/${ubuntu_repo_file}"<<-eof
deb https://${k8s_sources_repo_addr}/kubernetes/apt kubernetes-xenial main
eof
}
ubuntu_repo_update(){
  for i in $(eval echo {28..$k8s_ver_num}); do
    cat >> "/tmp/${ubuntu_repo_file}"<<-eof
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://mirrors.aliyun.com/kubernetes-new/core/stable/v1.${i}/deb/ /
eof
  done
}

# 定制软件源函数
create_repo(){
  # 接收参数
  local host_list="$*"

  # 生成所有源文件
  ubuntu_repo
  centos_repo

  # bug修复: 扩充全版本系列的软件源
  local k8s_ver_num=$(curl https://github.com/kubernetes/kubernetes/tags --max-time 10 -s | grep -vE 'alpha|-rc|-beta' | awk -F'.' '/se v/{print $2}' | sort -r | head -1)
  [ -z $k8s_ver_num ] && local k8s_ver_num=$(echo ${k8s_version} | awk -F'.' '{print $2}')
  # 扩充软件源信息
  if [ ${k8s_ver_num} -ge 28 ]; then
    centos_repo_update
    ubuntu_repo_update
    local add_keyfile="[ -d /etc/apt/keyrings ] || mkdir -p /etc/apt/keyrings ; curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg"
  else
    local add_keyfile=""
  fi
  # 遍历所有主机
  for ip in ${host_list}; do
    # 获取对应主机类型
    local os_type=$(ssh "${login_user}@${ip}" "grep -i ubuntu /etc/issue" >/dev/null && echo "Ubuntu" || echo "CentOS")
    if [ "${os_type}" == "Ubuntu" ]; then
      # 获取远程主机的hosts文件内容
      ssh "${login_user}@${ip}" "cat ${ubuntu_repo_dir}/${ubuntu_repo_file}" 2>/dev/null > "/tmp/list1"
      # 对比文件内容，确定是否拷贝文件
      ubuntu_list_status=$(diff /tmp/${ubuntu_repo_file} /tmp/list1 >/dev/null \
                          && echo "same" || echo "unsame")
      if [ "${ubuntu_list_status}" == "same" ]; then
        echo -e "\033[32m主机 ${ip} 软件源已同步，无需重复更新!!!\033[0m"
      else
        # 传输源文件
        scp "/tmp/${ubuntu_repo_file}" "${login_user}@${ip}:${ubuntu_repo_dir}/${ubuntu_repo_file}"
        # 更新软件源
        get_keyfile="curl -s https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add -"
        ssh "${login_user}@${ip}" "${get_keyfile}"
        ssh "${login_user}@${ip}" "${add_keyfile}; apt update -y"
        # 信息提示
        echo -e "\e[32mkubernetes集群主机 ${ip} 的软件源配置完毕 \e[0m"
      fi
    else
      # 获取远程主机的hosts文件内容
      ssh "${login_user}@${ip}" "cat ${centos_repo_dir}/${centos_repo_file}" > "/tmp/repo1"
      # 对比文件内容，确定是否拷贝文件
      centos_repo_status=$(diff /tmp/${centos_repo_file} /tmp/repo1 >/dev/null \
                          && echo "same" || echo "unsame")
      if [ "${centos_repo_status}" == "same" ]; then
        echo -e "\033[32m主机 ${ip} 软件源已同步，无需重复更新!!!\033[0m"
      else
        scp "/tmp/${centos_repo_file}" "${login_user}@${ip}:${centos_repo_dir}/${centos_repo_file}"
        ssh "${login_user}@${ip}" "yum makecache fast -y"
        echo -e "\e[32mkubernetes集群主机 ${ip} 的软件源配置完毕 \e[0m"
      fi
    fi
  done
}

# 查看k8s软件源支持的版本列表
k8s_version_list(){
  # 获取参数
  local os_type=$(ssh "${login_user}@${master1}" "grep -i ubuntu /etc/issue" >>/dev/null && echo "Ubuntu" || echo "CentOS")

  # 到远程主机执行获取版本的命令
  echo -e "\e[32m当前环境下可安装的kubernetes版本: \e[0m"
  echo_tag "=" 106
  if [ "${os_type}" == "Ubuntu" ];then
    ssh "${login_user}@${master1}" "apt-cache madison kubeadm | head -10"
  else
    ssh "${login_user}@${master1}" "yum list --showduplicates kubeadm | tail -10 | sort -r"
  fi
  echo_tag "=" 106
}

# 软件安装检测
check_k8s_softs_env(){
  # 接收参数
  local ip_addr="$1"
  local k8s_ver="$2"
  # 获取相关状态
  cmd_stat=$(ssh "${login_user}@${ip_addr}" "ls /usr/bin/kube{adm,ctl,let}" \
                                                >>/dev/null 2>&1 && echo exist || echo error)
  adm_ver=$(ssh "${login_user}@${ip_addr}" "kubeadm version" 2>/dev/null | awk -F'"' '{print $6}')
  ctl_ver=$(ssh "${login_user}@${ip_addr}" "kubectl version" 2>/dev/null | awk '/Client/{print $NF}')
  let_ver=$(ssh "${login_user}@${ip_addr}" "kubelet --version" 2>/dev/null | awk '{print $2}')
  # 检测状态
  if [[ "${cmd_stat}" == "exist" && "${adm_ver}" == "${k8s_ver}" && \
          "${ctl_ver}" == "${k8s_ver}" && "${let_ver}" == "${k8s_ver}" ]]; then
    echo "success"
  else
    echo "broken"
  fi
}

# 获取k8s软件最新版本
get_latest_k8s_version(){
   # 获取master节点的类型
   local os_type=$(ssh "${login_user}@${master1}" "grep -i ubuntu /etc/issue" >>/dev/null && echo "Ubuntu" || echo "CentOS") 
   # 获取k8s的kubeadm的最新版本
   if [ "${os_type}" == "Ubuntu" ]; then
     k8s_version_list | head -3 | tail -1 | awk '{print $3}' | awk -F'-' '{print $1}'
   else
     k8s_version_list | head -3 | tail -1 | awk '{print $2}' | awk -F'-' '{print $1}'
   fi
}

# 离线安装函数
k8s_install_offline(){
  # 接收参数
  local node_list=$(echo $*)
  # 传输文件
  for i in $node_list;
  do
    # bug修复: 检测远程主机是否存在环境
    local remote_host_status=$(check_k8s_softs_env "${i}" "v${k8s_version}")
    if [ "${remote_host_status}" == "broken" ]; then
      # 准备软件存放目录
      ssh "${login_user}@${i}" "[ -d ${target_dir} ] || mkdir -p ${target_dir}"
      # 判断远程主机的系统类型
      local os_type=$(ssh "${login_user}@${i}" "grep -i ubuntu /etc/issue" >/dev/null && echo "Ubuntu" || echo "CentOS")
      if [ "${os_type}" == "Ubuntu" ]; then
        # 传输离线文件到目标目录
        scp ${k8s_ubuntu_dir}/* ${login_user}@${i}:${target_dir}/
        # 远程主机安装离线文件, 为了保证离线安装成功，提前删除所有lock
        ssh "${login_user}@${i}" rm -f /var/lib/dpkg/lock*
        ssh "${login_user}@${i}" dpkg -i ${target_dir}/*
        ssh "${login_user}@${i}" dpkg -i ${target_dir}/libpam-modules_*.deb
        # bug修复: 安装完毕之后，解决底层软件库被破坏的问题
        ssh "${login_user}@${i}" "apt --fix-broken install -y"
      else
        # 传输离线文件到目标目录
        scp ${k8s_centos_dir}/* ${login_user}@${i}:${target_dir}/
        # 远程主机安装离线文件
        ssh "${login_user}@${i}" yum install -y ${target_dir}/*
      fi
      # 软件部署完毕后的提示信息
      echo -e "\e[32mkubernets节点 $i 软件安装完毕!!!\e[0m"
    else
      echo -e "\e[32mkubernets节点 $i 软件环境已存在，无需重复安装!!!\e[0m"
    fi
    # 设置远程主机kubelet服务为开机自启动
    ssh "${login_user}@${i}" "systemctl enable kubelet; systemctl start kubelet"
  done
}

# 定制k8s软件安装名称的后缀格式
k8s_softs_tail(){
  # 接收参数
  local os_type="$1"
  local ver_num="$2"
  local version="$3"

  # 判断操作系统类型，定制软件版本格式和远程执行命令
  if [ "${os_type}" == "Ubuntu" ]; then
    # bug修复: 不同版本的软件名后缀定制格式
    if [ ${ver_num} -ge 28 ]; then
      soft_tail='='${version}'-1.1'
    else
      soft_tail='='${version}'-00'
    fi
    cmd_type='apt'
    sub_cmd='rm -rf /var/lib/dpkg/lock*'
  else
    if [ ${ver_num} -ge 28 ]; then
      soft_tail='-'${version}'-150500.1.1'
    else
      soft_tail='-'${version}'-0'
    fi
    cmd_type='yum'
    sub_cmd='rm -rf /var/run/yum.pid'
  fi
}

# 在线安装函数
k8s_install_online(){
  # 接收参数
  local node_list="$*"

  # 获取需要安装的版本
  read -t 10 -p "请输入要部署的k8s版本(比如：1.28.1，空表示最新版-默认): " version
  [ -z $version ] && version="${k8s_version}"
  local ver_num=$(echo "${version}" | awk -F'.' '{print $2}')

  # 安装软件
  for i in $node_list; do
    # 判断远程主机的系统类型
    local os_type=$(ssh "${login_user}@${i}" "grep -i ubuntu /etc/issue" >/dev/null && echo "Ubuntu" || echo "CentOS")
    # 判断操作系统类型，定制软件版本格式和远程执行命令
    if [ "${os_type}" == "Ubuntu" ]; then
      # bug修复: 不同版本的软件名后缀定制格式
      k8s_softs_tail "${os_type}" "${ver_num}" "${version}"
    else
      k8s_softs_tail "${os_type}" "${ver_num}" "${version}"
    fi
    # 安装软件
    if [ -n "${version}" ];then
      full_cmd="${sub_cmd}; ${cmd_type} install -y kubeadm${soft_tail} kubectl${soft_tail} kubelet${soft_tail}"
    else
      full_cmd="${sub_cmd}; ${cmd_type} install -y kubeadm kubectl kubelet" 
    fi
    # bug修复: 检测远程主机是否存在环境
    # 因为在线安装的版本会有多种情况，所以，不能简单的使用单一version变量
    [ -n "${version}" ] && local d_version="${version}" || local d_version=$(get_latest_k8s_version)
    local remote_host_status=$(check_k8s_softs_env "${i}" "v${d_version}")
    if [ "${remote_host_status}" == "broken" ]; then
      ssh "${login_user}@${i}" ${full_cmd}
      echo -e "\e[32mkubernets节点 $i 软件安装完毕!!!\e[0m"
    else
      echo -e "\e[32mkubernets节点 $i 软件环境已存在，无需重复安装!!!\e[0m"
    fi
    # 设置远程主机kubelet服务为开机自启动
    ssh "${login_user}@${i}" "systemctl enable kubelet; systemctl start kubelet"
  done
}
# 安装软件函数
k8s_install(){
  # 接收参数
  local install_type="$1"
  local node_list="$2"

  # 判断是在线还是离线
  if [ "${install_type}" == "online" ];then
    k8s_install_online "${node_list}"
  else 
    k8s_install_offline "${node_list}"
  fi
}


# 提交镜像到harbor
push_image(){
  # 接收参数
  local is_use_offline_image="$1"
  local images_list="$2"
  
  # master节点登录harbor仓库
  echo -e "\e[33m登录本地harbor镜像仓库!!!\e[0m"
  harbor_login_cmd="docker login ${harbor_url} -u ${harbor_user} -p ${harbor_passwd}"
  ssh ${login_user}@${master_host} "${harbor_login_cmd}"
  
  # 生成指定仓库镜像列表
  get_proj_image_list "${harbor_k8s_repo}"

  # 镜像提交动作
  for i in ${images_list};do
    # 优化：获取和提交镜像前，检测harbor镜像文件是否存
    local check_image_status=$(grep "${harbor_addr}/${harbor_k8s_repo}/${i}" "${harbor_images_list_file}" >>/dev/null 2>&1 && echo "存在" || echo "不存在")
    if [ "${check_image_status}" == "不存在" ]; then
      # 判断离线在线的提交命令
      if [ "${is_use_offline_image}" == "yes" ];then
        docker_push_cmd="docker push $i"
      else
        docker_push_cmd="docker pull ${ali_mirror}/$i; docker tag ${ali_mirror}/$i ${harbor_addr}/${harbor_k8s_repo}/$i; docker push ${harbor_addr}/${harbor_k8s_repo}/$i; docker rmi ${ali_mirror}/$i"
      fi
      # 注意：我们目前的容器引擎是docker，后续使用containerd的时候，这里的命令需要调整
      ssh ${login_user}@${master_host} "${docker_push_cmd}" 2>/dev/null && push_status="ok"
      if [ "${push_status}" == "ok" ]; then
        echo -e "\e[32m指定版本的 $i 镜像文件推送到harbor镜像仓库: 成功!!!\e[0m"
      else
        echo -e "\e[31m指定版本的 $i 镜像文件推送到harbor镜像仓库: 失败!!!\e[0m"
      fi
    else
      echo -e "\e[32m指定版本的 ${i} 镜像文件在harbor镜像仓库已存在!!!\e[0m"
    fi
  done 
}

# 在线方式获取镜像
get_images_online(){
  # 获取参数
  local is_use_offline_image="$1"
  local k8s_version="$2"
  local master_host="$3"

  # 获取指定k8s环境的镜像文件
  get_image_cmd="kubeadm config images list --kubernetes-version=${k8s_version}"
  images_list=$(ssh ${login_user}@${master_host} "${get_image_cmd}" | awk -F'/' '{print $NF}')
  # 提交镜像到harbor
  echo -e "\e[33m将k8s集群初始化依赖镜像提交到本地harbor镜像仓库!!!\e[0m"
  push_image "${is_use_offline_image}" "${images_list}"

}

# 离线方式获取镜像
get_images_offline(){
  # 获取参数
  local is_use_offline_image="$1"
  local k8s_version="$2"
  local master_host="$3"

  # 检测本地是否存在镜像文件
  k8s_images_file="${images_dir}/${k8s_cluster_images}"
  if [ -f "${k8s_images_file}" ]; then
    # 传输镜像文件到master主机
    ssh ${login_user}@${master_host} "ls /tmp/${k8s_cluster_images}" >>/dev/null 2>&1 && file_status='ok'
    [ "$file_status" != "ok" ] && scp_file ${master_host} "${k8s_images_file}" "/tmp"
    # 导入镜像到master主机
    ssh ${login_user}@${master_host} "docker load < /tmp/${k8s_cluster_images}"
    # 获取要提交镜像名称
    get_image_cmd="docker images"
    images_list=$(ssh ${login_user}@${master_host} "${get_image_cmd}" | awk '/sswang/{print $1":"$2}')
    # 提交镜像到harbor
    echo -e "\e[33m将k8s集群初始化依赖镜像提交到本地harbor镜像仓库!!!\e[0m"
    push_image "${is_use_offline_image}" "${images_list}"
    
  else
    # 使用在线的镜像获取逻辑
    local is_use_offline_image="no"
    get_images_online "${is_use_offline_image}" "${k8s_version}" "${master_host}"
  fi
} 


# k8s镜像获取函数
get_images(){
  # 函数使用示例: get_images "${local_repo}" "${master1}"
  
  # 接收参数
  local image_repo="$1"
  local master_host="$2"
  local is_get_image="$3"
  local is_use_offline_image="$4"
  
  # 获取镜像版本
  local k8s_version=$(ssh ${login_user}@${master_host} "kubeadm version" | awk -F'\"v' '{print $2}' | awk -F'\"' '{print $1}')
  [ "${image_repo}" == "no" ] && return
  # 交互判断：是否提前获取镜像
  if [ "${is_get_image}" == "yes" ]; then
    if [ "${is_use_offline_image}" == "yes" ];then
      echo -e "\e[33m传输本地离线镜像文件到目标主机\e[0m"
      get_images_offline "${is_use_offline_image}" "${k8s_version}" "${master_host}"
    elif [ "${is_use_offline_image}" == "no" ];then
      get_images_online "${is_use_offline_image}" "${k8s_version}" "${master_host}"
    fi
  elif [ "${is_get_image}" == "no" ];then
    echo "不需要提前获取镜像文件，直接下一步"
  fi
  
}

# k8s集群初始化函数
cluster_create(){
  # 接受参数
  local local_repo="$1"

  # 检测远程主机的状态
  local remote_cluster_addr=$(ssh ${login_user}@${master1} "kubectl cluster-info" \
                                  2>/dev/null \
                                  | awk -F'[//|:]' '/plane/{print $(NF-1)}')
  local expect_cluster_addr="${master1}"
  if [ "${remote_cluster_addr}" == "${expect_cluster_addr}" ]; then
    echo -e "\e[33m指定节点的k8s集群初始化操作已完成，无需重复初始化操作!!!\e[0m"
  else
    cluster_create_process "${local_repo}"
  fi
}

# k8s集群初始化过程函数
cluster_create_process(){
  # 接收参数：主要是是否使用本地镜像仓库的值
  local local_repo_status="$1"
 
  # 定制镜像仓库地址
  [ "${local_repo_status}" == "no" ] && repo_addr="${ali_mirror}" || repo_addr="${harbor_addr}/${harbor_k8s_repo}"

  # 获取k8s集群版本信息
  local k8s_version=$(ssh ${login_user}@${master1} "kubeadm version" | awk -F'\"v' '{print $2}' | awk -F'\"' '{print $1}')
  
  # 对k8s的版本进行判断
  # 如果部署的k8s版本大于1.24，则使用cri_socket参数，否则不使用
  check_num=$(echo "${k8s_version}" | cut -d'.' -f2)
  [ "${check_num}" -lt "24" ] && local cri_options=""

  # 构造集群初始化命令(考虑信息的临时存储)
  echo -e "\e[33m开始执行k8s集群初始化操作!!!\e[0m"
  cluster_init_cmd="kubeadm init --kubernetes-version=${k8s_version} \
                                 --apiserver-advertise-address=${master1} \
                                 --image-repository=${repo_addr} \
                                 --service-cidr=${K8S_SVC_CIDR_DEFINE} \
                                 --pod-network-cidr=${K8S_POD_CIDR_DEFINE} \
                                 --ignore-preflight-errors=Swap ${cri_options}"
  ssh ${login_user}@${master1} "${cluster_init_cmd}" | tee "/tmp/${cluster_init_msg_file}"
  # 提示信息输出 --cri-socket unix:///var/run/cri-dockerd.sock
  echo -e "\e[33m其他节点添加到当前k8s集群的时候，请在默认命令后添加如下参数：\e[0m"
  echo -e "\e[33m      ${cri_options}\e[0m"
  echo -e "\e[32m\n当前k8s集群master节点初始化成功!!!!!!\e[0m"
}

# master环境收尾函数
k8s_master_tail(){
  # 传递master节点收尾脚本到远程主机
  scp "${ext_scripts_dir}/${k8s_master_tail_scripts}"  ${login_user}@${master1}:/tmp/

  # 远程master节点执行脚本文件
  echo -e "\e[33m开始执行k8s集群初始化后master节点收尾操作!!!\e[0m"
  ssh ${login_user}@${master1} "/bin/bash /tmp/${k8s_master_tail_scripts}"

  # 测试master节点收尾动作
  ssh ${login_user}@${master1} "kubectl get nodes; rm -rf /tmp/${k8s_master_tail_scripts}"
  echo -e "\e[32m\n当前k8s集群master节点初始化收尾动作执行完毕!!!!!!\e[0m"
}

# 检测节点存活
check_k8s_node(){
  # 获取参数
  local node_ip="$1"
  local node_name=$(grep ${node_ip} ${host_file} | awk '{print $NF}')
  
  # 确认节点是否存在
  local node_status=$(ssh ${login_user}@${master1} "kubectl get nodes ${node_name}" \
                     >>/dev/null 2>&1 && echo "exist" || echo "noexist")
  echo "${node_status}"
}

# node加入集群函数
add_k8s_node(){
  # 使用示例：add_k8s_node "${host_role}" "${ip_list}"
  local node_role="$1"
  local node_list="$2"

  # 对k8s的版本进行判断
  # 如果部署的k8s版本大于1.24，则使用cri_socket参数，否则不使用
  check_num=$(echo "${k8s_version}" | cut -d'.' -f2)
  [ "${check_num}" -lt "24" ] && local cri_options=""

  # 获取增加节点命令
  if [ "${node_role}" == "master" ];then
    echo "获取master节点初始化命令内容"
  elif [ "${node_role}" == "node" ];then
    msg_txt=$(grep -A2 'm join' "/tmp/${cluster_init_msg_file}")
  fi
  sub_cmd=$(echo ${msg_txt} | sed 's#\\ ##')
  add_node_cmd="${sub_cmd} ${cri_options}"
  echo -e "\e[33m开始执行k8s集群加入工作节点操作!!!\e[0m"
  
  # bug修复: 获取master节点类型
  local master_os_type=$(ssh ${login_user}@${master1} "grep -i ubuntu /etc/issue" >> /dev/null \
                                                       && echo "Ubuntu" || echo "CentOS")
  for node in ${node_list};
  do
    # 节点存活性检测
    local remote_node_status=$(check_k8s_node "${node}")
    if [ "${remote_node_status}" == "noexist" ]; then
      # bug修复: 获取node节点类型
      local node_os_type=$(ssh ${login_user}@${node} "grep -i ubuntu /etc/issue" >> /dev/null \
                                                       && echo "Ubuntu" || echo "CentOS")
      # bug修复: 解决Centos主机因为resolv.conf文件，导致kubelet无法启动
      if [[ "${master_os_type}" == "Ubuntu" && "${node_os_type}" == "CentOS" ]]; then
        scp "${scripts_dir}/${ext_scripts_dir}/${k8s_node_centos_tail_scripts}" "${login_user}@${node}:/etc/profile.d/"
        # 多做一次文件检测
        local resolv_file='/run/systemd/resolve/resolv.conf'
        ssh "${login_user}@${node}" "[ -f ${resolv_file} ] || /bin/bash /etc/profile.d/${k8s_node_centos_tail_scripts}"
      fi
      # 工作节点增加的逻辑
      ssh ${login_user}@$node "${add_node_cmd}"
      echo -e "\e[32m节点 $node 加入当前k8s集群完毕!!!\e[0m"
      # 测试工作节点是否加入集群
      # sleep 5
      # local add_node_status=$(check_k8s_node "${node}")
      # if [ "${remote_node_status}" == "noexist" ]; then
      #   echo -e "\e[31m节点 $node 加入当前k8s集群失败!!!\e[0m"
        # return
      # else
        # 控制节点增加的逻辑-待考虑
      #   echo -e "\e[32m节点 $node 加入当前k8s集群完毕!!!\e[0m"
      # fi
    else
      echo -e "\e[33m节点 $node 已在当前k8s集群，无需重复增加!!!\e[0m"
    fi
  done
  # 测试节点添加集群效果
}

# 一键集群初始化功能函数
onekey_cluster_init(){
  # 接收参数
  local is_online="$1"
  local local_repo="$2"
  # 获取k8s集群主节点的系统类型
  local remote_status=$(ssh "${login_user}@${master1}" "grep -i ubuntu /etc/issue")
  [ -n "${remote_status}" ] && local os_type="Ubuntu" || local os_type="CentOS"
  # 执行k8s集群定制软件源操作
  create_repo "${all_k8s_list}"
  # 执行k8s集群软件安装操作
  k8s_version_list
  k8s_install "${is_online}" "${all_k8s_list}"
  # 执行k8s集群初始化操作
  get_images "${local_repo}" "${master1}" "${default_get_image_type}" "${default_use_image_type}"
  cluster_create "${local_repo}"
  # 执行k8s集群初始化收尾
  k8s_master_tail
  # 执行node加入K8s集群操作
  add_k8s_node "node" "${k8s_node_list}"
  # 定制K8s集群网络解决方案操作
  k8s_network_install "${default_network_type}"
}

