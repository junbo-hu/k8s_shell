#!/bin/bash
# *************************************
# 功能: Shell脚本模板
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 版本: v0.1
# 日期: 2023-07-10
# *************************************

# 基础环境变量定制
image_repo='kubernetes-register.sswang.com'
docker_repo_addr='mirror.tuna.tsinghua.edu.cn'
default_repo_addr='download.docker.com'
# 自动识别操作系统类型，设定软件部署的命令
status=$(grep -i ubuntu /etc/issue)
[ -n "${status}" ] && os_type="Ubuntu" || os_type="CentOS"
[ "${os_type}" == "Ubuntu" ] && cmd_type="apt" || cmd_type="yum"

# 软件源定制函数
ubuntu_repo(){
  # 在ubuntu环境下配置docker-ce软件源
  apt-get -y install apt-transport-https ca-certificates curl software-properties-common
  curl -fsSL https://${docker_repo_addr}/docker-ce/linux/ubuntu/gpg | sudo apt-key add -
  add-apt-repository "deb [arch=amd64] https://${docker_repo_addr}/docker-ce/linux/ubuntu $(lsb_release -cs) stable"
  apt-get -y update 
}

centos_repo(){
  # 在centos环境下配置docker-ce软件源
  yum install -y yum-utils device-mapper-persistent-data lvm2
  yum-config-manager --add-repo https://${docker_repo_addr}/docker-ce/linux/centos/docker-ce.repo
  sed -i "s#https://${default_repo_addr}#https://${docker_repo_addr}/docker-ce#g" /etc/yum.repos.d/docker-ce.repo
  yum makecache fast
}

softs_base(){
  # 定制docker的软件源
  if [ "${os_type}" == "Ubuntu" ]; then
    ubuntu_repo
  else
    centos_repo
  fi
}

# 软件安装函数
softs_install(){
  # docker-ce 软件的部署
  # 获取当前docker的软件版本列表
  echo -e "\e[33m当前系统所支持的软件可用安装版本列表\e[0m"
  if [ "${os_type}" == "Ubuntu" ]; then
    apt-cache madison docker-ce | head -n 10 | awk '{print $1,"\t",$3}'
  else
    yum list docker-ce --showduplicates | sort -r | awk '/docker/ {print $1,"\t",$2}' | head -n10
  fi
  # 优化：删除影响docker软件安装的lock 或 pid文件
  [ "${os_type}" == "Ubuntu" ] && rm -rf /var/lib/dpkg/lock* /var/cache/apt/archives/lock || rm -rf /var/run/yum.pid

  # 安装docker软件
  echo "CentOS环境下Docker软件的版本格式: 24.0.4"
  echo "Ubuntu环境下Docker软件的版本格式: 5:24.0.4-1~ubuntu.20.04~focal"
  read -t 5 -p "请输入您要部署的软件版本(空表示默认最新版本): " version
  if [ -n "${version}" ]; then
    [ "${os_type}" == "Ubuntu" ] && soft_tail='='${version} || soft_tail='-'${version}
    "${cmd_type}" install -y "docker-ce${soft_tail}"
  else
    "${cmd_type}" install -y docker-ce
  fi
  # 软件安装的后置命令
  systemctl restart docker; systemctl enable docker
  
}

# 镜像加速器配置函数
image_speed(){
  # docker 镜像加速器配置
  cat > /etc/docker/daemon.json <<-EOF
{
  "registry-mirrors": [
    "http://74f21445.m.daocloud.io",
    "https://registry.docker-cn.com",
    "http://hub-mirror.c.163.com",
    "https://docker.mirrors.ustc.edu.cn"
  ], 
  "insecure-registries": ["${image_repo}"], 
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF
  # docker服务重启
  systemctl restart docker
}


# 检测容器环境函数
docker_check(){
  # 检测当前主机容器环境是否正常
  process_type=$(docker info | grep 'p D' | awk '{print $NF}')
  if [ "${process_type}" == "systemd" ]; then
    echo -e "\e[32mDocker软件部署成功\e[0m" 
  else
    echo -e "\e[31mDocker软件部署失败\e[0m"
    exit
  fi
}

# 主函数
main(){
  softs_base
  softs_install
  image_speed
  docker_check 
}

# 执行主函数
main
