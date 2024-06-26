#!/bin/bash
# *************************************
# 功能: Shell脚本模板
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 版本: v0.1
# 日期: 2023-07-17
# *************************************
# 问题：混合功能的脚本编写
# - 涉及到软件环境的部署 - 单独一个脚本 - 远程主机执行
# - 涉及到软件服务的操作 - 单独一个脚本 - 在管理节点上执行
# 步骤：
# - 先把所有功能放到一个脚本中(到远程主机上执行)
# - 根据功能属性的特质，进行脚本的拆分。



# 基本环境定制
compose_cmd='docker-compose'
compose_bin="/usr/bin/${compose_cmd}"

harbor_name='harbor'
harbor_version='v2.5.0'
harbor_image="harbor.${harbor_version}.tar.gz"
harbor_softs="harbor-offline-installer-${harbor_version}.tgz"
harbor_site='https://github.com/goharbor/harbor/releases/download'
harbor_url="${harbor_site}/${harbor_version}/${harbor_softs}"


softs_dir='/data/softs'
server_dir='/data/server'
harbor_conf="${harbor_name}.yml"
harbor_pass='123456'
harbor_data_dir="${server_dir}/${harbor_name}/data"
harbor_service_file='harbor.service'
harbor_service_path="/lib/systemd/system/${harbor_service_file}"
harbor_compose_file='docker-compose.yml'


harbor_admin='admin'
harbor_admin_passwd='123456'
harbor_user='sswang'
harbor_passwd='A12345678a'
harbor_my_repo='sswang'
harbor_k8s_repo='google_containers'

harbor_addr=$(grep register /etc/hosts | awk '{print $1}')
harbor_url="http://${harbor_addr}"
harbor_ver='api/version'
add_user_api='api/v2.0/users'
add_proj_api='api/v2.0/projects'

# 自动识别操作系统类型，设定软件部署的命令
status=$(grep -i ubuntu /etc/issue)
[ -n "${status}" ] && os_type="Ubuntu" || os_type="CentOS"
[ "${os_type}" == "Ubuntu" ] && cmd_type="apt" || cmd_type="yum"

# 自动获取主机名
host_name=$(awk '/register/{print $2}' /etc/hosts)

# harbor依赖环境
compose_install(){
  # 部署 harbor依赖的compose环境
  [ "${os_type}" == "Ubuntu" ] && ${cmd_type} update || ${cmd_type} makecache fast
  [ ! -f "${compose_bin}" ] && ${cmd_type} install -y ${compose_cmd} jq
}

# harbor文件获取
get_harbor(){
  # 获取harbor软件文件
  if [ ! -f "${softs_dir}/${harbor_softs}" ]; then
    cd "${softs_dir}"
    wget "${harbor_url}"
  fi

  # 文件的解压
  [ ! -d "${server_dir}" ] && mkdir -p "${server_dir}"
  [ -d "${server_dir}/${harbor_name}" ] && rm -rf "${server_dir}/${harbor_name}"
  tar xf "${softs_dir}/${harbor_softs}" -C "${server_dir}"
}

# 提前导入harbor镜像
image_load(){
  cd "${server_dir}/${harbor_name}"
  docker load < "${harbor_image}"
}
# harbor环境初始化
config_harbor(){
  # harbor环境的配置文件定制
  cd "${server_dir}/${harbor_name}"
  mv "${harbor_conf}.tmpl" "${harbor_conf}"
  sed -i "/name: /s#hostname: .*#hostname: $host_name#" "${harbor_conf}"
  sed -i 's/^https/# https/' "${harbor_conf}"
  sed -i 's/port: 443/# port: 443/' "${harbor_conf}"
  sed -i 's/certificate:/# certificate:/' "${harbor_conf}"
  sed -i 's/private_key:/# private_key:/' "${harbor_conf}"
  sed -i "s#harbor_admin_password: .*#harbor_admin_password: ${harbor_pass}#" "${harbor_conf}"
  sed -i "s#data_volume: .*#data_volume: ${harbor_data_dir}#" "${harbor_conf}"
  # harbor的环境初始化
  "${server_dir}/${harbor_name}/prepare"
  "${server_dir}/${harbor_name}/install.sh"
  sleep 5
  "${compose_bin}" ps
  sleep 3
  "${compose_bin}" down
}

# harbor服务定制
harbor_serv(){
  # 定制harbor服务启动文件
  cat > "${harbor_service_path}" <<-eof
[Unit]
Description=Harbor
After=docker.service systemd-networkd.service systemd-resolved.service
Requires=docker.service
Documentation=http://github.com/vmware/harbor

[Service]
Type=simple
Restart=on-failure
RestartSec=5
#需要注意harbor的安装位置
ExecStart=${compose_bin} --file ${server_dir}/${harbor_name}/${harbor_compose_file} up
ExecStop=${compose_bin} --file ${server_dir}/${harbor_name}/${harbor_compose_file} down

[Install]
WantedBy=multi-user.target
eof
  # 服务启动
  systemctl daemon-reload
  systemctl enable harbor
  systemctl start harbor

}

# harbor用户定制
harbor_user(){
  # 接收环境变量
  user="$1"
  passwd="$2"
  # 定制harbor管理员用户配置
  cat > /tmp/add_user.json<<-eof
{
  "username": "${user}",
  "realname": "${user}",
  "email": "${user}@sswang.com",
  "password": "${passwd}",
  "comment": "普通用户"
}
eof
  # 创建用户
  curl -s -H "Content-Type: application/json" -u "${harbor_admin}:${harbor_admin_passwd}" -X POST "${harbor_url}/${add_user_api}" -d @/tmp/add_user.json
  # 检查用户
  result=$(curl -s -H "Content-Type: application/json" -u "${harbor_admin}:${harbor_admin_passwd}" "${harbor_url}/${add_user_api}" | grep "${user}")
  if [ "${result}" != "" ]; then
    echo -e "\e[32m${user}用户创建成功!!!\e[0m"
  else
    echo -e "\e[31m${user}用户创建失败!!!\e[0m"
    exit
  fi
}

# harbor镜像仓库
harbor_proj(){
  # 接收环境变量
  user="$1"
  passwd="$2"
  repo="$3"
  # 定制harbor镜像仓库配置
  cat > /tmp/add_repo.json <<-eof
{
  "project_name": "${repo}",
  "public": true
}
eof
  # 创建harbor镜像仓库
  curl -s -H "Content-Type: application/json" -u "${user}:${passwd}" -X POST "${harbor_url}/${add_proj_api}" -d @/tmp/add_repo.json
  # 检测harbor镜像仓库
  result=$(curl -s -H "Content-Type: application/json" -u "${user}:${passwd}" "${harbor_url}/${add_proj_api}" | grep "${repo}")
  if [ "${result}" != "" ]; then
    echo -e "\e[32m${repo}仓库创建成功!!!\e[0m"
  else
    echo -e "\e[31m${repo}仓库创建失败!!!\e[0m"
    exit
  fi
}

# harbor环境检查
harbor_check(){
  # 检查harbor的应用环境
  echo -e "\e[31m检测harbor程序状态是否正常\e[0m"
  # status=$(ssh root@${harbor_addr} "systemctl is-active harbor")
  status=$(systemctl is-active harbor)
  if [ "${status}" == "active" ]; then
    echo -e "\e[32mharbor镜像仓库环境部署成功!!!\e[0m"
  else
    echo -e "\e[31mharbor镜像仓库环境部署失败!!!\e[0m"
    exit
  fi
  # 检查harbor的api服务环境
  echo -e "\e[31m检测harbor服务状态是否正常\e[0m"
  msg=$(curl -s "${harbor_url}/${harbor_ver}")
  ver=$(echo "${msg}" | jq -r ".version")
  mark=''
  while [ "${ver}" != "v2.0" ]; do
    printf "progress: [%-40s]\r" "${mark}"
    sleep 0.2
    mark="#${mark}"
    msg=$(curl -s "${harbor_url}/${harbor_ver}")
    ver=$(echo "${msg}" | jq -r ".version")
  done
  echo -e "\e[32m检测harbor API服务状态正常\e[0m"
}

# 主函数
main(){
  # harbor基础环境准备
  if [ -f "${compose_bin}" ]; then
    echo -e "\e[32mharbor主机已经部署 docker-compose 环境\e[0m"
  else
    compose_install
  fi
  # harbor环境部署
  # status=$(ssh root@${harbor_addr} "systemctl is-active harbor")
  status=$(systemctl is-active harbor)
  if [ "${status}" == "active" ]; then
    echo -e "\e[32mharbor镜像仓库环境部署成功!!!\e[0m"
  else
    get_harbor
    image_load
    config_harbor
    harbor_serv
    harbor_check
  fi
  # harbor仓库服务定制
  harbor_user "${harbor_user}" "${harbor_passwd}"
  harbor_proj "${harbor_user}" "${harbor_passwd}" "${harbor_my_repo}"  
  harbor_proj "${harbor_user}" "${harbor_passwd}" "${harbor_k8s_repo}"  
}

# 执行主函数
main
