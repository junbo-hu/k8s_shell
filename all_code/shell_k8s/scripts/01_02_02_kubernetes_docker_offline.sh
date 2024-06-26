#!/bin/bash
# *************************************
# 功能: Shell脚本模板
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 版本: v0.1
# 日期: 2023-12-30
# *************************************

# 基础环境变量
local docker_hostlist="$*"
local docker_linshi_dir='/tmp/docker'
local default_image_repo=$(awk '/register/{print $2}' ${host_file})
# 解压文件
untar_docker_file(){
  # 判断是否存在文件，若存在，则解压
  if [ -f "${docker_dir}/${docker_tar_file}" ];then
    [ -d "${docker_linshi_dir}" ] && rm -rf "${docker_linshi_dir}"/* || mkdir "${docker_linshi_dir}"
    tar xf "${docker_dir}/${docker_tar_file}" -C "${docker_linshi_dir}"
  else
    echo -e "\e[33m没有指定版本的docker离线软件已存在!!!\e[0m"
    return
  fi
}

# 创建服务文件
create_docker_conf(){
  # 定制docker的service配置文件
  cat > "${docker_linshi_dir}/${docker_service_conf}"<<-"eof"
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target
Wants=network-online.target
[Service]
Type=notify
ExecStart=/usr/bin/dockerd
ExecReload=/bin/kill -s HUP $MAINPID
TimeoutStartSec=0
RestartSec=2
Restart=always
StartLimitBurst=3
StartLimitInterval=60s
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
Delegate=yes
KillMode=process
OOMScoreAdjust=-500
[Install]
WantedBy=multi-user.target
eof

  # docker 镜像加速器配置
  cat > "${docker_linshi_dir}/${docker_daemon_json}" <<-EOF
{
  "registry-mirrors": [
    "http://74f21445.m.daocloud.io",
    "https://registry.docker-cn.com",
    "http://hub-mirror.c.163.com",
    "https://docker.mirrors.ustc.edu.cn"
  ],
  "insecure-registries": ["${default_image_repo}"],
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF
}

# 传输命令和配置
scp_docker_file(){
  # 接收参数：
  local ip="$1"
  # 为了保证操作的正常执行，采用关闭远程服务的方式。
  ssh "${login_user}@${ip}" "systemctl stop docker.service" 2>/dev/null
  # 传输docker配置文件和docker基础命令到所有的k8s节点主机
  echo -e "\e[33m向${ip}主机传递 Docker 软件所依赖的所有文件\e[0m"
  scp "${docker_linshi_dir}"/docker/* "${login_user}@${ip}:/usr/bin/"
  scp "${docker_linshi_dir}/${docker_service_conf}" "${login_user}@${ip}:${service_conf_dir}/"
  # 传递daemon.json文件
  ssh "${login_user}@${ip}" "[ -d ${docker_daemon_dir} ] || mkdir -p ${docker_daemon_dir}"
  scp "${docker_linshi_dir}/${docker_daemon_json}" "${login_user}@${ip}:${docker_daemon_dir}/${docker_daemon_json}"
}


# 检测docker服务
check_docker_serv(){
  # 接收参数：
  local ip="$1"
  
  # 检测当前主机容器环境是否正常
  process_type=$(ssh ${login_user}@${ip} "docker info" | grep 'p D' | awk '{print $NF}')
  if [ "${process_type}" == "systemd" ]; then
    echo -e "\e[32m${ip}主机 Docker 软件部署成功\e[0m"
  else
    echo -e "\e[31m${ip}主机 Docker 软件部署失败\e[0m"
    exit
  fi
}

# 启动docker服务
start_docker_serv(){
  # 接收参数：
  local ip="$1"
  echo -e "\e[33m${ip}主机设置 Docker 服务开机自启动\e[0m"
  ssh "${login_user}@${ip}" "systemctl daemon-reload;systemctl enable ${docker_service_conf} "
  ssh "${login_user}@${ip}" "systemctl restart ${docker_service_conf}"
  check_docker_serv "${ip}"
}

# 主函数
main(){
  # 加压docker文件
  untar_docker_file
  # 创建docker配置
  create_docker_conf

  # 开始指定主机列表的后续动作
  for ip in ${docker_hostlist} ; do
    remote_dockerd_status=$(ssh "${login_user}@${ip}" "systemctl is-active ${docker_service_conf}")
    if [ "${remote_dockerd_status}" == "active" ]; then
      echo -e "\e[32m${ip} 主机Docker服务已部署成功\e[0m"
    else
      scp_docker_file "${ip}"
      start_docker_serv "${ip}"
    fi
  done
}

# 执行主函数
main
