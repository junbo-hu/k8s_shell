#!/bin/bash
# *************************************
# 功能: harbor远程主机执行的过程
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

softs_dir='/data/softs'
server_dir='/data/server'
harbor_conf="${harbor_name}.yml"
harbor_pass='123456'
harbor_data_dir="${server_dir}/${harbor_name}/data"
harbor_service_file='harbor.service'
harbor_service_path="/lib/systemd/system/${harbor_service_file}"
harbor_compose_file='docker-compose.yml'

# 自动识别操作系统类型，设定软件部署的命令
status=$(grep -i ubuntu /etc/issue)
[ -n "${status}" ] && os_type="Ubuntu" || os_type="CentOS"
[ "${os_type}" == "Ubuntu" ] && cmd_type="apt" || cmd_type="yum"

# 自动获取主机名
host_name=$(awk '/register/{print $2}' /etc/hosts)

# harbor文件获取
untar_harbor(){
  # 文件的解压
  [ ! -d "${server_dir}" ] && mkdir -p "${server_dir}"
  # bug修复: 避免harbor文件的重复解压
  if [ -d "${server_dir}/${harbor_name}" ]; then
    if [ -f "${server_dir}/${harbor_name}/${harbor_conf}" ]; then
       echo -e "\e[32mharbor软件已经解压成功，无需重复解压!!!\e[0m"
    else
      rm -rf "${server_dir}/${harbor_name}"
      echo -e "\e[33mharbor软件包解压时间有些长，请稍等....\e[0m"
      tar xf "${softs_dir}/${harbor_softs}" -C "${server_dir}"
    fi
  else
    echo -e "\e[33mharbor软件包解压时间有些长，请稍等....\e[0m"
    tar xf "${softs_dir}/${harbor_softs}" -C "${server_dir}"
  fi
}

# 提前导入harbor镜像
image_load(){
  cd "${server_dir}/${harbor_name}"
  # bug修复: 解决harbor环境重置时候的docker镜像长时间等待
  local harbor_image_num=$(docker images | grep goharbor | wc -l)
  if [ "${harbor_image_num}" == "15" ]; then
    echo -e "\e[32mharbor相关镜像文件已经导入到当前主机环境!!!\e[0m"
  else
    echo -e "\e[33m导入harbor环境依赖的镜像文件，时间有些长，请稍等....\e[0m"
    docker load < "${harbor_image}"
  fi
}

# 提升harbor默认的安装速度
edit_harbor_install(){
  # bug修复: 提升harbor默认的安装速度
  local sub_add='[ $(docker images | grep goharbor | wc -l) != 15 ]'
  sed -i "/docker load/s#docker #${sub_add} \&\& docker #" ${server_dir}/${harbor_name}/install.sh
}

# harbor环境初始化
config_harbor(){
  # harbor环境的配置文件定制
  echo -e "\e[33m定制harbor环境的配置文件....\e[0m"
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
  echo -e "\e[33mharbor环境初始化操作....\e[0m"
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
  echo -e "\e[33m定制harbor服务开机自启动配置....\e[0m"
  systemctl daemon-reload
  systemctl enable harbor
  systemctl start harbor

}

# 主函数
main(){
  # harbor环境部署
  status=$(systemctl is-active harbor)
  if [ "${status}" == "active" ]; then
    echo -e "\e[32mharbor镜像仓库环境部署成功!!!\e[0m"
  else
    untar_harbor
    image_load
    # 提高harbor安装的速度
    edit_harbor_install
    config_harbor
    harbor_serv
  fi
}

# 执行主函数
main
