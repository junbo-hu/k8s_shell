#!/bin/bash
# *************************************
# 功能: 相关离线文件的获取
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 版本: v0.1
# 日期: 2023-12-20
# *************************************

# 离线目录的创建
offline_dir_create(){
  # 创建离线文件目录
  [ -d "${images_dir}" ] || mkdir -p "${images_dir}"

  # 创建expect目录
  [ -d "${expect_centos_dir}" ] || mkdir -p "${expect_centos_dir}"
  [ -d "${expect_ubuntu_dir}" ] || mkdir -p "${expect_ubuntu_dir}"

  # 创建docker-ce目录
  [ -d "${docker_dir}" ] || mkdir -p "${docker_dir}"

  # 创建cri-dockerd目录
  [ -d "${cri_dockerd_dir}" ] || mkdir -p "${cri_dockerd_dir}"
  
  # 创建harbor目录
  [ -d "${harbor_dir}" ] || mkdir -p "${harbor_dir}"
  
  # 创建compose目录
  [ -d "${compose_dir}" ] || mkdir -p "${compose_dir}"

  # 创建kubernetes目录
  [ -d "${k8s_centos_dir}" ] || mkdir -p "${k8s_centos_dir}"
  [ -d "${k8s_ubuntu_dir}" ] || mkdir -p "${k8s_ubuntu_dir}"
  
  # 提前获取依赖关系的命令
  [ "${os_type}" == "Ubuntu" ] && "${cmd_type}" install -y apt-rdepends
}

# 定制离线获取expect软件
get_offline_expect(){
  # 根据部署服务器的类型，自动获取软件到特定目录
  if [[ "${os_type}" == "Ubuntu" ]]; then
    cd "${expect_ubuntu_dir}"
    [ -f ${expect_ubuntu_dir}/expect*.deb ] && (echo -e "\e[33mexpect文件已存在!!!\e[0m"; return)
    sudo "${cmd_type}" download $(apt-rdepends expect | grep -Ev "^ |debconf")
  else
    [ -f ${expect_centos_dir}/expect*.rpm ] && (echo -e "\e[33mexpect文件已存在!!!\e[0m"; return)
    "${cmd_type}" install --downloadonly --downloaddir="${expect_centos_dir}" expect
    rm -f "${expect_centos_dir}/*.yumtx"
  fi
}

# 定制离线获取docker软件
get_offline_docker_default(){
  # 判断离线目录是否正常
  if [ -d "${docker_dir}" ]; then
    # 获取docker离线文件
    if [ -f "${docker_dir}/${docker_tar_file}" ]; then
      echo -e "\e[33m指定版本的docker离线软件已存在!!!\e[0m"
    else
      wget "${docker_tar_url}" -O "${docker_dir}/${docker_tar_file}"
    fi
  else
    echo -e "\e[33m指定docker离线文件目录不存在，请先创建目录!!!\e[0m"
    return
  fi
}

# 获取docker软件包的最新列表
get_docker_version_online(){
  # 从docker网站获取文件列表
  # 为了保证有信息输出，这里后缀必须有/
  curl --connect-timeout 10 -s "${docker_site_url}/" | awk -F'"' '{print $2}' | grep -E 'docker-[0-9]' | tail -n 10
  read -p "请输入您要获取的docker版本号(示例: 24.0.1 ): " my_ver
  echo "========================================================"
}

# 获取任意版本docker软件
get_offline_docker(){
  local linshi_arg="$1"
  if [[ -n "${linshi_arg}" && "${linshi_arg}" == "${docker_version}" ]]; then
    # 使用默认的docker版本文件
    get_offline_docker_default
  else
    # 使用定制的docker版本文件
    local docker_version="${linshi_arg}"
    local docker_tar_file="docker-${docker_version}.tgz"
    local docker_tar_url="${docker_site_url}/${docker_tar_file}"
    local docker_dir="${softs_dir}/docker-ce/${docker_version}"
    # 关于定制的版本目录，需要自己创建，而不是全局方式创建
    [ ! -d "${docker_dir}" ] && mkdir -p "${docker_dir}"
    get_offline_docker_default
  fi
}

# 定制离线获取cri-dockerd软件
get_offline_cridockerd_default(){
  # 判断离线目录是否正常
  if [ -d "${cri_dockerd_dir}" ]; then
    # 获取docker离线文件
    if [ -f "${cri_dockerd_dir}/${cri_softs_name}" ]; then
      echo -e "\e[33m指定版本的cri-dockerd离线软件已存在!!!\e[0m"
    else
      wget "${cri_softs_url}" -O "${cri_dockerd_dir}/${cri_softs_name}"
    fi
  else
    echo -e "\e[33m指定cri-dockerd离线文件目录不存在，请先创建目录!!!\e[0m"
    return
  fi
}

# 获取cri-dockerd软件
get_cridockerd_version_online(){
  # 从cri-dockerd网站获取文件列表
  curl --connect-timeout 10 -s "${cri_github_tags}" | awk -F'>|<' '/h2 data/{print $(NF-4)}'
  read -p "请输入您要获取的cri-dockerd版本号(示例: 0.3.8 ): " my_ver
  echo "========================================================"
}

# 获取任意版本cri-dockerd软件
get_offline_cridockerd(){
  local linshi_arg="$1"
  if [[ -n "${linshi_arg}" && "${linshi_arg}" == "${cri_dockerd_version}" ]]; then
    # 使用默认的docker版本文件
    get_offline_cridockerd_default
  else
    # 使用定制的docker版本文件
    local cri_dockerd_version="${linshi_arg}"
    local cri_softs_name="${cri_name}-${cri_dockerd_version}.amd64.tgz"
    local cri_softs_url="${cri_softs_site}/v${cri_dockerd_version}/${cri_softs_name}"
    local cri_dockerd_dir="${softs_dir}/cri_dockerd/${cri_dockerd_version}"
    # 关于定制的版本目录，需要自己创建，而不是全局方式创建
    [ ! -d "${cri_dockerd_dir}" ] && mkdir -p "${cri_dockerd_dir}"
    get_offline_cridockerd_default
  fi
}


# 获取默认版本的harbor软件
get_offline_harbor_default(){
  # 判断离线目录是否正常
  if [ -d "${harbor_dir}" ]; then
    # 获取docker离线文件
    if [ -f "${harbor_dir}/${harbor_softs}" ]; then
      echo -e "\e[33m指定版本的harbor离线软件已存在!!!\e[0m"
    else
      wget "${harbor_url}" -O "${harbor_dir}/${harbor_softs}"
    fi
  else
    echo -e "\e[33m指定harbor离线文件目录不存在，请先创建目录!!!\e[0m"
    return
  fi
}

# 获取harbor软件
get_harbor_version_online(){
  # 从harbor网站获取文件列表
  curl --connect-timeout 10 -s "${harbor_github_tags}" | awk -F'>|<' '/h2 data/{print $(NF-4)}' | grep -v 'rc'
  read -p "请输入您要获取的harbor版本号(示例: v2.5.0 ): " my_ver
  echo "========================================================"
}

# 获取任意版本harbor软件
get_offline_harbor(){
  local linshi_arg="$1"
  if [[ -n "${linshi_arg}" && "${linshi_arg}" == "${harbor_version}" ]]; then
    # 使用默认的docker版本文件
    get_offline_harbor_default
  else
    # 使用定制的docker版本文件
    local harbor_version="${linshi_arg}"
    local harbor_softs="harbor-offline-installer-${harbor_version}.tgz"
   
    local harbor_url="${harbor_site}/${harbor_version}/${harbor_softs}"
    local harbor_dir="${softs_dir}/harbor/${harbor_version}"
    # 关于定制的版本目录，需要自己创建，而不是全局方式创建
    [ ! -d "${harbor_dir}" ] && mkdir -p "${harbor_dir}"
    get_offline_harbor_default
  fi
}

# 获取默认版本的compose软件
get_offline_compose_default(){
  # 判断离线目录是否正常
  if [ -d "${compose_dir}" ]; then
    # 获取docker-compose离线文件
    if [ -f "${compose_dir}/${compose_file_name}" ]; then
      echo -e "\e[33m指定版本的docker-compose离线软件已存在!!!\e[0m"
    else
      wget "${compose_softs_site}" -O "${compose_dir}/${compose_file_name}"
    fi
  else
    echo -e "\e[33m指定docker-compose离线文件目录不存在，请先创建目录!!!\e[0m"
    return
  fi
}

# 获取compose软件
get_compose_version_online(){
  # 从compose网站获取文件列表
  curl --connect-timeout 10 -s "${compose_github_tags}" | awk -F'>|<' '/h2 data/{print $(NF-4)}'
  read -p "请输入您要获取的docker-compose版本号(示例: v2.23.0 ): " my_ver
  echo "========================================================"
}

# 获取任意版本docker-compose软件
get_offline_compose(){
  local linshi_arg="$1"
  if [[ -n "${linshi_arg}" && "${linshi_arg}" == "${compose_version}" ]]; then
    # 使用默认的docker-compose版本文件
    get_offline_compose_default
  else
    # 使用定制的docker-compose版本文件
    local compose_version="${linshi_arg}"
    local compose_softs_site="${compose_github_url}/releases/download/${compose_version}/${compose_file_name}"
    local compose_dir="${softs_dir}/compose/${compose_version}"
    # 关于定制的版本目录，需要自己创建，而不是全局方式创建
    [ ! -d "${compose_dir}" ] && mkdir -p "${compose_dir}"
    get_offline_compose_default
  fi
}

# 获取kubernetes默认版本的软件
get_offline_k8s_default(){
  # 根据部署服务器的类型，自动获取软件到特定目录
  if [[ "${os_type}" == "Ubuntu" ]]; then
    # 检测文件是否已存在
    cd "${k8s_ubuntu_dir}"
    [ -f ${k8s_ubuntu_dir}/kubeadm*.deb ] && (echo -e "\e[33mkubernetes相关文件已存在!!!\e[0m"; return)
    # 增加软件源的配置
    if [ ! -f "${ubuntu_repo_dir}/${ubuntu_repo_file}" ]; then
      echo "deb https://${k8s_sources_repo_addr}/kubernetes/apt kubernetes-xenial main" \
        > "${ubuntu_repo_dir}/${ubuntu_repo_file}"
      /usr/bin/apt update
    fi
    # 下载离线文件
    sudo "${cmd_type}" download $(apt-rdepends kubeadm | grep -Ev "^ |debconf")
  else
    # 这里的思路，暂时是有问题的 -- 部署服务器和k8s集群必须一样。
    if [ -f ${k8s_centos_dir}/*kubeadm*.rpm ]; then
      echo -e "\e[33mkubernetes相关文件已存在!!!\e[0m"
    else
      # 增加软件源的配置
      if [ ! -f "${centos_repo_dir}/${centos_repo_file}" ]; then
        local basearch=$(uname -m)
        cat > "${centos_repo_dir}/${centos_repo_file}" <<-eof
[kubernetes]
name=kubernetes
baseurl=https://${k8s_sources_repo_addr}/kubernetes/yum/repos/kubernetes-el7-$basearch
enabled=1
eof
        /usr/bin/yum makecache fast
      fi
      # 下载离线文件
      "${cmd_type}" install --downloadonly --downloaddir="${k8s_centos_dir}" kubeadm
      rm -f "${k8s_centos_dir}/*.yumtx"
    fi
  fi
  echo -e "\e[32m已获取${k8s_version}版本的kubernetes软件\e[0m"
}


# 获取kubernetes指定版本的软件
get_offline_k8s_define(){
  if [ -n "${k8s_version}" ];then
    # 判断操作系统类型
    if [ "${os_type}" == "Ubuntu" ]; then
      soft_tail='='${k8s_version}'-00'
      softs_list="kubeadm${soft_tail} kubectl${soft_tail} kubelet${soft_tail}"
      cd "${k8s_ubuntu_dir}"
      # 检测文件是否已存在
      [ -f ${k8s_ubuntu_dir}/kubeadm*.deb ] && (echo -e "\e[33mkubernetes相关文件已存在!!!\e[0m"; return)
      # 增加软件源的配置
      if [ ! -f "${ubuntu_repo_dir}/${ubuntu_repo_file}" ]; then
        echo "deb https://${k8s_sources_repo_addr}/kubernetes/apt kubernetes-xenial main" \
          > "${ubuntu_repo_dir}/${ubuntu_repo_file}"
        /usr/bin/apt update
      fi
      # 下载离线文件
      sudo apt download $(apt-rdepends kubeadm | grep -Ev "^ |debconf")
      rm -f "kube"[acl]*
      # 获取指定版本的几个软件
      sudo apt download ${softs_list}
    else
      soft_tail='-'${k8s_version}'-0'
      softs_list="kubeadm${soft_tail} kubectl${soft_tail} kubelet${soft_tail}"
      # 检测文件是否已存在
      if [ -f ${k8s_centos_dir}/*kubeadm*.rpm ]; then
        echo -e "\e[33mkubernetes相关文件已存在!!!\e[0m"
      else
        # 增加软件源的配置
        if [ ! -f "${centos_repo_dir}/${centos_repo_file}" ]; then
          local basearch=$(uname -m)
          cat > "${centos_repo_dir}/${centos_repo_file}" <<-eof
[kubernetes]
name=kubernetes
baseurl=https://${k8s_sources_repo_addr}/kubernetes/yum/repos/kubernetes-el7-$basearch
enabled=1
eof
          /usr/bin/yum makecache fast
        fi
        # 下载离线文件
        yum install --downloadonly --downloaddir="${k8s_centos_dir}" ${softs_list}
        rm -f "${k8s_centos_dir}/*.yumtx"
      fi
    fi
  fi
  echo -e "\e[32m已获取${k8s_version}版本的kubernetes软件\e[0m"
}

# k8s软件版本获取函数
get_k8s_version(){
  # 到远程主机执行获取版本的命令
  echo -e "\e[32m当前环境下可安装的kubernetes版本: \e[0m"
  echo "========================================================="
  kubeadm_version_tags="${k8s_sources_repo_addr}/kubernetes/apt/pool/"
  curl --connect-timeout 10 -s "${kubeadm_version_tags}" | \
       awk -F'_|-' '/kubeadm/{print $2}' | grep '1.2' | \
       sort -rut'.' --parallel=2 | head -n10
  read -p "请输入您要获取的kubeadm版本号(示例: 1.28.2 ): " my_ver
  echo "========================================================="

}
# 获取kubernetes指定版本的软件
get_offline_k8s(){
  local linshi_arg="$1"
  if [[ -n "${linshi_arg}" && "${linshi_arg}" == "${k8s_version}" ]]; then
    # 使用默认的kubernetes版本文件
    get_offline_k8s_default
  else
    # 使用定制的kubernetes版本文件
    local k8s_version="${linshi_arg}"
    local k8s_dir="${softs_dir}/kubernetes/${k8s_version}"
    local k8s_centos_dir="${k8s_dir}/centos"
    local k8s_ubuntu_dir="${k8s_dir}/ubuntu"
    # 关于定制的版本目录，需要自己创建，而不是全局方式创建
    [ -d "${k8s_centos_dir}" ] || mkdir -p "${k8s_centos_dir}"
    [ -d "${k8s_ubuntu_dir}" ] || mkdir -p "${k8s_ubuntu_dir}"
    get_offline_k8s_define 
  fi
}

