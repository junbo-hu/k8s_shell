#!/bin/bash
# *************************************
# 功能: K8s集群主机部署CRI服务
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 版本: v0.1
# 日期: 2023-07-11
# *************************************

# 基础环境变量
cri_hostlist="$*"
cri_dockerd_linshi_dir='/tmp/cir_dockerd'

# 获取CRI软件
get_cri_softs(){
  # 从github上获取最新版本的cri软件
  [ ! -d "${softs_dir}" ] && mkdir "${softs_dir}"
  # 如果本地目录没有 cri文件，那么就直接去互联网获取
  if [ ! -f "${softs_dir}/${cri_softs_name}" ] ; then
    cd "${softs_dir}"
    wget "${cri_softs_url}"
  fi
  # 如果本地存在，则直接解压该文件即可
  tar xf "${softs_dir}/${cri_softs_name}" -C /tmp
}

# 解压文件
untar_cridockerd_file(){
  # 判断是否存在文件，若存在，则解压
  if [ -f "${cri_dockerd_dir}/${cri_softs_name}" ];then
    [ -d "${cri_dockerd_linshi_dir}" ] && rm -rf "${cri_dockerd_linshi_dir}"/* || mkdir "${cri_dockerd_linshi_dir}"
    tar xf "${cri_dockerd_dir}/${cri_softs_name}" -C "${cri_dockerd_linshi_dir}"
  else
    echo -e "\e[33m没有指定版本的cri-dockerd离线软件!!!\e[0m"
    return
  fi
}

# 定制CRI配置
create_cri_conf(){
  # 定制cri-dockerd的service配置文件
  [ -f "${cri_dockerd_linshi_dir}/${cri_service_conf}" ] || cat > "${cri_dockerd_linshi_dir}/${cri_service_conf}" <<-eof
[Unit]
Description=CRI Interface for Docker Application Container Engine
Documentation=https://docs.mirantis.com
After=network-online.target firewalld.service docker.service
Wants=network-online.target
[Service]
Type=notify
ExecStart=/usr/local/bin/cri-dockerd --pod-infra-container-image=registry.cn-hangzhou.aliyuncs.com/google_containers/pause:3.9 --network-plugin=cni --cni-conf-dir=/etc/cni/net.d --cni-bin-dir=/opt/cni/bin --container-runtime-endpoint=unix:///var/run/cri-dockerd.sock --cri-dockerd-root-directory=/var/lib/dockershim --docker-endpoint=unix:///var/run/docker.sock --cri-dockerd-root-directory=/var/lib/docker
ExecReload=/bin/kill -s HUP $MAINPID
TimeoutSec=0
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
[Install]
WantedBy=multi-user.target
eof
  # 定制cri-dockerd的socket配置文件
  [ -f "${cri_dockerd_linshi_dir}/${cri_socket_conf}" ] || cat > "${cri_dockerd_linshi_dir}/${cri_socket_conf}" <<-eof
[Unit]
Description=CRI Docker Socket for the API
PartOf=cri-docker.service

[Socket]
ListenStream=/var/run/cri-dockerd.sock
SocketMode=0660
SocketUser=root
SocketGroup=docker

[Install]
WantedBy=sockets.target
eof
}

# 传输CRI配置
scp_cri_conf(){
  # 接收参数：
  local ip="$1"
  # 传输cri配置文件到指定的k8s节点主机
  ssh "${login_user}@${ip}" "systemctl stop cri-docker.service" 2>/dev/null
  echo -e "\e[33m向${ip}主机传递 Cri-dockerd 软件所依赖的所有文件\e[0m"
  scp "${cri_dockerd_linshi_dir}/${cri_name}/${cri_name}" "${login_user}@${ip}:${service_bin_dir}/"
  scp "${cri_dockerd_linshi_dir}/${cri_service_conf}" "${login_user}@${ip}:${service_conf_dir}/"
  scp "${cri_dockerd_linshi_dir}/${cri_socket_conf}" "${login_user}@${ip}:${service_conf_dir}/"
}

# 检测CRI服务
check_cri_serv(){
  # 检测当前主机cri环境是否正常
  host_addr="$1"
  local status=$(ssh "${login_user}@${host_addr}" "systemctl is-active ${cri_service_conf}")
  if [ "${status}" == "active" ]; then
    echo -e "\e[32m${host_addr} 主机CRI服务部署成功\e[0m"
  else
    echo -e "\e[31m${host_addr} 主机CRI服务部署失败\e[0m"
    exit
  fi
}

# 启动CRI服务
deploy_cri_serv(){
  # 接收参数：
  local ip="$1"
  echo -e "\e[33m${ip}主机设置 Cri-dockerd 服务开机自启动\e[0m"
  ssh "${login_user}@${ip}" "systemctl daemon-reload;systemctl enable ${cri_service_conf}" 
  ssh "${login_user}@${ip}" "systemctl restart ${cri_service_conf}"
  check_cri_serv "${ip}"
}


# 主函数
main(){
  untar_cridockerd_file
  create_cri_conf
  for ip in ${cri_hostlist} ; do
    cri_dockerd_status=$(ssh "${login_user}@${ip}" "systemctl is-active ${cri_service_conf}")
    if [ "${cri_dockerd_status}" == "active" ]; then
      echo -e "\e[32m${ip} 主机CRI服务已部署成功\e[0m"
    else
      scp_cri_conf "${ip}"
      deploy_cri_serv "${ip}"
    fi
  done
}

# 执行主函数
main
